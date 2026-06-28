//! Boots the Galakrond environment. Faithful Rust port of the PowerShell
//! orchestration (Update-GitRepos / Invoke-DockerPreflight /
//! Wait-ForContainerHealthy / Start-DockerPhase*), streaming progress to the UI
//! as `orchestration` events instead of writing to a log window.

use std::process::Stdio;
use std::time::Duration;

use serde::Serialize;
use tauri::{AppHandle, Emitter};
use tokio::io::{AsyncBufReadExt, AsyncRead, BufReader};

use crate::config::{Config, DockerPhase, PhaseService};

const EVENT: &str = "orchestration";

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Progress {
    /// Logical stage: "preflight" | "git" | a docker phase name | "done".
    pub phase: String,
    /// The individual service/repo/container this event is about, if any.
    pub service: Option<String>,
    /// "started" | "ok" | "warn" | "error" | "info".
    pub status: String,
    pub message: Option<String>,
}

pub(crate) fn emit(
    app: &AppHandle,
    phase: &str,
    service: Option<&str>,
    status: &str,
    message: Option<String>,
) {
    let _ = app.emit(
        EVENT,
        Progress {
            phase: phase.to_string(),
            service: service.map(|s| s.to_string()),
            status: status.to_string(),
            message,
        },
    );
}

/// Runs `wsl bash -c "<script>"` and returns (exit_code, combined_output).
async fn wsl_bash(script: &str) -> (i32, String) {
    run_cmd("wsl", &["bash", "-c", script]).await
}

async fn run_cmd(program: &str, args: &[&str]) -> (i32, String) {
    match tokio::process::Command::new(program).args(args).output().await {
        Ok(o) => {
            let mut out = String::from_utf8_lossy(&o.stdout).into_owned();
            out.push_str(&String::from_utf8_lossy(&o.stderr));
            (o.status.code().unwrap_or(-1), out.trim().to_string())
        }
        Err(e) => (-1, format!("failed to spawn {program}: {e}")),
    }
}

/// Reads a child pipe line by line, emitting each as a "log" event.
async fn pump<R: AsyncRead + Unpin>(app: AppHandle, phase: String, service: String, reader: R) {
    let mut lines = BufReader::new(reader).lines();
    while let Ok(Some(line)) = lines.next_line().await {
        if !line.trim().is_empty() {
            emit(&app, &phase, Some(&service), "log", Some(line));
        }
    }
}

/// Runs `wsl bash -c "<script>"`, streaming stdout+stderr to the UI in real time
/// as "log" events. Returns the exit code.
async fn run_streaming(app: &AppHandle, phase: &str, service: &str, script: &str) -> i32 {
    let mut child = match tokio::process::Command::new("wsl")
        .args(["bash", "-c", script])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
    {
        Ok(c) => c,
        Err(e) => {
            emit(app, phase, Some(service), "error", Some(format!("spawn wsl: {e}")));
            return -1;
        }
    };

    let stdout = child.stdout.take();
    let stderr = child.stderr.take();
    let mut pumps = Vec::new();
    if let Some(out) = stdout {
        pumps.push(tokio::spawn(pump(
            app.clone(),
            phase.to_string(),
            service.to_string(),
            out,
        )));
    }
    if let Some(err) = stderr {
        pumps.push(tokio::spawn(pump(
            app.clone(),
            phase.to_string(),
            service.to_string(),
            err,
        )));
    }

    let code = child
        .wait()
        .await
        .ok()
        .and_then(|s| s.code())
        .unwrap_or(-1);
    for p in pumps {
        let _ = p.await;
    }
    code
}

/// Classifies a non-zero `git pull` so the UI says what to do, not just FAILED.
fn git_hint(out: &str) -> &'static str {
    if out.contains("untracked working tree files would be overwritten") {
        "fichiers non suivis bloquent le fast-forward (deplacer/supprimer)"
    } else if out.contains("local changes") || out.contains("Your local changes") {
        "changements locaux non commites (commit ou stash)"
    } else if out.contains("Not possible to fast-forward")
        || out.contains("diverged")
        || out.contains("non-fast-forward")
    {
        "branche divergee de l'upstream (merge manuel requis)"
    } else if out.contains("no tracking information") || out.contains("no upstream") {
        "aucun upstream configure pour cette branche"
    } else if out.contains("Could not resolve host")
        || out.contains("unable to access")
        || out.contains("Connection timed out")
        || out.contains("Could not read from remote")
    {
        "erreur reseau vers le remote"
    } else if out.contains("Not a git repository") || out.contains("No such file or directory") {
        "le chemin n'est pas un depot git"
    } else {
        "ignore (voir details)"
    }
}

/// `wsl -e true`, then retry `docker info` 5x/2s. Errors abort the boot.
async fn preflight(app: &AppHandle) -> Result<(), String> {
    emit(app, "preflight", None, "started", Some("Verification WSL + Docker".into()));

    let (code, out) = run_cmd("wsl", &["-e", "true"]).await;
    if code != 0 {
        let msg = format!("WSL indisponible: {out}");
        emit(app, "preflight", None, "error", Some(msg.clone()));
        return Err(msg);
    }

    for attempt in 1..=5 {
        let (code, _) = wsl_bash("docker info 2>&1").await;
        if code == 0 {
            emit(app, "preflight", None, "ok", Some("Daemon Docker pret".into()));
            return Ok(());
        }
        emit(
            app,
            "preflight",
            None,
            "warn",
            Some(format!("Docker pas pret (tentative {attempt}/5)")),
        );
        if attempt < 5 {
            tokio::time::sleep(Duration::from_secs(2)).await;
        }
    }

    let msg = "Daemon Docker injoignable apres 5 tentatives".to_string();
    emit(app, "preflight", None, "error", Some(msg.clone()));
    Err(msg)
}

/// Pulls every configured repo in parallel. Always non-fatal (matches PS).
async fn git_pull(app: &AppHandle, repos: &[String]) {
    emit(
        app,
        "git",
        None,
        "started",
        Some(format!("git pull --ff-only ({} depots)", repos.len())),
    );

    let tasks = repos.iter().map(|repo| {
        let app = app.clone();
        let repo = repo.clone();
        async move {
            let (code, out) = wsl_bash(&format!("cd '{repo}' && git pull --ff-only 2>&1")).await;
            if code == 0 {
                let short = if out.contains("Already up to date") {
                    "deja a jour"
                } else {
                    "mis a jour"
                };
                emit(&app, "git", Some(&repo), "ok", Some(short.into()));
            } else {
                emit(&app, "git", Some(&repo), "warn", Some(git_hint(&out).into()));
            }
        }
    });

    futures::future::join_all(tasks).await;
    emit(app, "git", None, "ok", Some("Pull termine".into()));
}

/// Polls `docker inspect ... .State.Health.Status` until healthy or timeout.
async fn wait_healthy(app: &AppHandle, names: &[String], timeout_secs: u64) -> Result<(), String> {
    let timeout = if timeout_secs == 0 { 60 } else { timeout_secs };

    for name in names {
        emit(
            app,
            "health",
            Some(name),
            "started",
            Some(format!("Attente healthcheck (timeout {timeout}s)")),
        );

        let deadline = tokio::time::Instant::now() + Duration::from_secs(timeout);
        let mut healthy = false;
        while tokio::time::Instant::now() < deadline {
            let (_, status) = wsl_bash(&format!(
                "docker inspect {name} --format '{{{{.State.Health.Status}}}}' 2>/dev/null"
            ))
            .await;
            if status.trim() == "healthy" {
                healthy = true;
                break;
            }
            tokio::time::sleep(Duration::from_secs(2)).await;
        }

        if !healthy {
            let msg = format!("{name} pas healthy dans les {timeout}s");
            emit(app, "health", Some(name), "error", Some(msg.clone()));
            return Err(msg);
        }
        emit(app, "health", Some(name), "ok", Some("healthy".into()));
    }
    Ok(())
}

/// Starts one service: creates its network (best effort) then runs the command.
async fn start_service(app: &AppHandle, phase: &str, svc: &PhaseService) -> Result<(), String> {
    emit(app, phase, Some(&svc.name), "started", None);

    if let Some(net) = &svc.network {
        let _ = wsl_bash(&format!("docker network create '{net}' 2>/dev/null; true")).await;
    }

    let code = run_streaming(
        app,
        phase,
        &svc.name,
        &format!("cd '{}' && {} 2>&1", svc.path, svc.command),
    )
    .await;
    if code != 0 {
        let msg = format!("exit {code}");
        emit(app, phase, Some(&svc.name), "error", Some(msg.clone()));
        return Err(msg);
    }
    emit(app, phase, Some(&svc.name), "ok", None);
    Ok(())
}

/// Restarts a single dashboard service by re-running its backing docker service.
pub async fn restart(app: AppHandle, cfg: &Config, dashboard_name: &str) -> Result<(), String> {
    let svc = cfg
        .services
        .iter()
        .find(|s| s.name == dashboard_name)
        .ok_or_else(|| format!("service inconnu: {dashboard_name}"))?;
    let docker_name = svc
        .docker_service
        .clone()
        .ok_or_else(|| format!("{dashboard_name} n'a pas de dockerService"))?;
    let phase_svc = cfg
        .docker_phases
        .iter()
        .flat_map(|p| &p.services)
        .find(|ps| ps.name == docker_name)
        .ok_or_else(|| format!("service docker introuvable: {docker_name}"))?;

    emit(&app, "restart", Some(&docker_name), "started", Some("Redemarrage".into()));
    start_service(&app, "restart", phase_svc).await?;
    emit(&app, "restart", None, "ok", Some(format!("{docker_name} redemarre")));
    Ok(())
}

/// Runs a single docker phase (parallel fan-out or sequential), aborting on the
/// first failure - just like the PowerShell `throw`.
async fn run_phase(app: &AppHandle, phase: &DockerPhase) -> Result<(), String> {
    if !phase.wait_healthy.is_empty() {
        wait_healthy(
            app,
            &phase.wait_healthy,
            phase.health_timeout_seconds.unwrap_or(60),
        )
        .await?;
    }

    let mode = if phase.parallel { "parallel" } else { "sequentiel" };
    emit(app, &phase.name, None, "started", Some(format!("Phase {mode}")));

    if phase.parallel {
        let tasks = phase.services.iter().map(|svc| {
            let app = app.clone();
            let phase_name = phase.name.clone();
            let svc = svc.clone();
            async move { start_service(&app, &phase_name, &svc).await }
        });
        let results = futures::future::join_all(tasks).await;
        let failed: Vec<String> = results.into_iter().filter_map(|r| r.err()).collect();
        if !failed.is_empty() {
            let msg = format!("Phase '{}' en echec", phase.name);
            emit(app, &phase.name, None, "error", Some(msg.clone()));
            return Err(msg);
        }
    } else {
        for svc in &phase.services {
            start_service(app, &phase.name, svc).await?;
        }
    }

    emit(app, &phase.name, None, "ok", None);
    Ok(())
}

/// Full boot sequence: preflight -> git pull -> ordered docker phases.
pub async fn run(app: AppHandle, cfg: Config) -> Result<(), String> {
    preflight(&app).await?;

    if let Some(gp) = &cfg.git_pull {
        if gp.enabled && !gp.repos.is_empty() {
            git_pull(&app, &gp.repos).await;
        }
    }

    for phase in &cfg.docker_phases {
        run_phase(&app, phase).await?;
    }

    // Stack is up - launch the Windows companion apps (best-effort).
    crate::launchers::launch_all(&app, &cfg);

    emit(&app, "done", None, "ok", Some("Environnement demarre".into()));
    Ok(())
}
