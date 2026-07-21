//! Boots the Galakrond environment. Faithful Rust port of the PowerShell
//! orchestration (Update-GitRepos / Invoke-DockerPreflight /
//! Wait-ForContainerHealthy / Start-DockerPhase*), streaming progress to the UI
//! as `orchestration` events instead of writing to a log window.

use std::process::Stdio;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
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
    // Persist to the current log file first (choke point for every event), then
    // stream it to the UI.
    crate::logger::write(phase, service, status, message.as_deref());
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

/// Recognizes docker/BuildKit image-build output so a long first-run build
/// (which makes `docker compose up` block for minutes) can be surfaced to the
/// UI instead of looking frozen.
fn is_build_line(line: &str) -> bool {
    line.contains("[+] Building")
        || line.contains("load build definition")
        || line.contains("=> [")
        || line.contains("exporting to image")
}

/// Reads a child pipe line by line, emitting each as a "log" event. The first
/// time a build line is seen (shared across stdout+stderr via `build_announced`)
/// it also emits a one-shot "info" so the user knows a multi-minute image build
/// is underway rather than a hang.
async fn pump<R: AsyncRead + Unpin>(
    app: AppHandle,
    phase: String,
    service: String,
    reader: R,
    build_announced: Arc<AtomicBool>,
) {
    let mut lines = BufReader::new(reader).lines();
    while let Ok(Some(line)) = lines.next_line().await {
        if line.trim().is_empty() {
            continue;
        }
        if is_build_line(&line) && !build_announced.swap(true, Ordering::SeqCst) {
            emit(
                &app,
                &phase,
                Some(&service),
                "info",
                Some("Build de l'image en cours (premiere fois, peut durer plusieurs minutes)".into()),
            );
        }
        emit(&app, &phase, Some(&service), "log", Some(line));
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
    let build_announced = Arc::new(AtomicBool::new(false));
    let mut pumps = Vec::new();
    if let Some(out) = stdout {
        pumps.push(tokio::spawn(pump(
            app.clone(),
            phase.to_string(),
            service.to_string(),
            out,
            build_announced.clone(),
        )));
    }
    if let Some(err) = stderr {
        pumps.push(tokio::spawn(pump(
            app.clone(),
            phase.to_string(),
            service.to_string(),
            err,
            build_announced.clone(),
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

    crate::logger::start_session(&format!("restart {docker_name}"));
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
            async move {
                let res = start_service(&app, &phase_name, &svc).await;
                (svc.name.clone(), svc.optional, res)
            }
        });
        let results = futures::future::join_all(tasks).await;
        // Only non-optional failures fail the phase; optional ones just warn.
        let mut hard_failed: Vec<String> = Vec::new();
        for (name, optional, res) in results {
            if let Err(e) = res {
                if optional {
                    emit(app, &phase.name, Some(&name), "warn", Some(format!("optionnel, ignore ({e})")));
                } else {
                    hard_failed.push(name);
                }
            }
        }
        if !hard_failed.is_empty() {
            let msg = format!("Phase '{}' en echec ({})", phase.name, hard_failed.join(", "));
            emit(app, &phase.name, None, "error", Some(msg.clone()));
            return Err(msg);
        }
    } else {
        for svc in &phase.services {
            if let Err(e) = start_service(app, &phase.name, svc).await {
                if svc.optional {
                    emit(app, &phase.name, Some(&svc.name), "warn", Some(format!("optionnel, ignore ({e})")));
                } else {
                    return Err(e);
                }
            }
        }
    }

    emit(app, &phase.name, None, "ok", None);
    Ok(())
}

/// Waits for the browsable services (those with a `url`) to actually answer
/// before the companion apps launch, so Chrome tabs don't load against a
/// not-yet-listening port. Reuses the `health` probes (healthUrl, TCP fallback).
/// Non-fatal like the PowerShell `Wait-ForPorts`: on timeout it warns and lets
/// the boot proceed.
async fn wait_for_services_ready(app: &AppHandle, cfg: &Config) {
    let wanted: Vec<&str> = cfg
        .services
        .iter()
        .filter(|s| s.url.is_some())
        .map(|s| s.name.as_str())
        .collect();
    if wanted.is_empty() {
        return;
    }

    emit(
        app,
        "services",
        None,
        "started",
        Some(format!("Attente de disponibilite ({} services)", wanted.len())),
    );

    let deadline = tokio::time::Instant::now() + Duration::from_secs(120);
    loop {
        let statuses = crate::health::probe_all(&cfg.services).await;
        let pending: Vec<String> = statuses
            .iter()
            .filter(|s| s.url.is_some() && s.health == crate::health::Health::Down)
            .map(|s| s.name.clone())
            .collect();

        if pending.is_empty() {
            emit(app, "services", None, "ok", Some("Services prets".into()));
            return;
        }

        if tokio::time::Instant::now() >= deadline {
            emit(
                app,
                "services",
                None,
                "warn",
                Some(format!(
                    "Timeout: {} (lancement des apps quand meme)",
                    pending.join(", ")
                )),
            );
            return;
        }

        for name in &pending {
            emit(app, "services", Some(name), "info", Some("en attente".into()));
        }
        tokio::time::sleep(Duration::from_secs(1)).await;
    }
}

/// Full boot sequence: preflight -> git pull -> ordered docker phases.
pub async fn run(app: AppHandle, cfg: Config) -> Result<(), String> {
    crate::logger::start_session("boot");
    preflight(&app).await?;

    if let Some(gp) = &cfg.git_pull {
        if gp.enabled && !gp.repos.is_empty() {
            git_pull(&app, &gp.repos).await;
        }
    }

    // Run each phase in order. A failure in an `optional` phase (mail, api,
    // frontends) is non-fatal: we log a warning and keep going so a single
    // broken service can't take the rest of the environment down with it. Only
    // a non-optional prerequisite phase (infrastructure) aborts the boot.
    let mut degraded: Vec<String> = Vec::new();
    for phase in &cfg.docker_phases {
        if let Err(e) = run_phase(&app, phase).await {
            if phase.optional {
                emit(
                    &app,
                    &phase.name,
                    None,
                    "warn",
                    Some(format!("Phase '{}' en echec, on continue ({e})", phase.name)),
                );
                degraded.push(phase.name.clone());
            } else {
                return Err(e);
            }
        }
    }

    // Wait for the browsable services to answer, then launch the Windows
    // companion apps (best-effort).
    wait_for_services_ready(&app, &cfg).await;
    crate::launchers::launch_all(&app, &cfg);

    if degraded.is_empty() {
        emit(&app, "done", None, "ok", Some("Environnement demarre".into()));
    } else {
        emit(
            &app,
            "done",
            None,
            "warn",
            Some(format!(
                "Environnement demarre en mode degrade (echec: {})",
                degraded.join(", ")
            )),
        );
    }
    Ok(())
}
