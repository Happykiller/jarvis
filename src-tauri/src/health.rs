//! Service readiness probing. Ports the lessons baked into the PowerShell
//! `Test-Port` / `Test-HealthUrl` helpers:
//!
//! * An open TCP port is NOT proof an HTTP service is ready (NestJS binds :3000
//!   before its modules load; Vite accepts connections while still compiling).
//! * When a `healthUrl` exists, ANY HTTP response - including 4xx/5xx - means
//!   "listening" (GET /graphql returns 400 but proves NestJS is up). Only a
//!   refused/timed-out connection means "not ready".
//! * Without a `healthUrl` but with a `container`, we ask Docker whether that
//!   container is running (for port-less workers like eudora).
//! * Otherwise we fall back to a plain TCP port check.

use std::net::SocketAddr;
use std::time::Duration;

use serde::Serialize;
use tokio::net::TcpStream;

use crate::config::ServiceDef;

#[derive(Debug, Clone, Serialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum Health {
    Up,
    Down,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ServiceStatus {
    pub name: String,
    pub port: u16,
    pub url: Option<String>,
    pub health: Health,
    /// Round-trip latency of the probe in milliseconds, when reachable.
    pub latency_ms: Option<u64>,
    /// Backing docker service, if this one can be restarted.
    pub docker_service: Option<String>,
}

/// TCP connect to 127.0.0.1:port with a timeout. Unlike the naive PowerShell
/// pattern, tokio's connect fully completes the handshake, so a refused
/// connection cannot masquerade as success.
async fn test_port(port: u16, timeout: Duration) -> bool {
    let addr: SocketAddr = ([127, 0, 0, 1], port).into();
    matches!(
        tokio::time::timeout(timeout, TcpStream::connect(addr)).await,
        Ok(Ok(_))
    )
}

/// HTTP GET where any response status counts as ready. Only transport-level
/// failures (refused, timeout, DNS) count as down.
async fn test_health_url(client: &reqwest::Client, url: &str) -> bool {
    client.get(url).send().await.is_ok()
}

/// Asks Docker (through WSL) whether a container is running. Used for services
/// with no listening port, like the eudora background worker. Args are passed
/// directly to `wsl` (no shell) so the `{{...}}` format string needs no quoting.
async fn test_container(name: &str) -> bool {
    match tokio::process::Command::new("wsl")
        .args(["docker", "inspect", name, "--format", "{{.State.Running}}"])
        .output()
        .await
    {
        Ok(o) => String::from_utf8_lossy(&o.stdout).trim() == "true",
        Err(_) => false,
    }
}

/// Probes a single service: `healthUrl` (HTTP) first, then a `container` state
/// check, else a plain TCP port connect.
pub async fn probe(client: &reqwest::Client, svc: &ServiceDef) -> ServiceStatus {
    let started = tokio::time::Instant::now();
    let timeout = Duration::from_millis(1500);

    let up = if let Some(url) = &svc.health_url {
        test_health_url(client, url).await
    } else if let Some(container) = &svc.container {
        test_container(container).await
    } else {
        test_port(svc.port, timeout).await
    };

    ServiceStatus {
        name: svc.name.clone(),
        port: svc.port,
        url: svc.url.clone(),
        health: if up { Health::Up } else { Health::Down },
        latency_ms: if up {
            Some(started.elapsed().as_millis() as u64)
        } else {
            None
        },
        docker_service: svc.docker_service.clone(),
    }
}

/// Probes every service concurrently.
pub async fn probe_all(services: &[ServiceDef]) -> Vec<ServiceStatus> {
    let client = reqwest::Client::builder()
        .timeout(Duration::from_millis(1500))
        .build()
        .unwrap_or_else(|_| reqwest::Client::new());

    let futures = services.iter().map(|svc| probe(&client, svc));
    futures::future::join_all(futures).await
}
