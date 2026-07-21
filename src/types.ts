// Shapes returned by the Rust backend (see src-tauri/src/config.rs & health.rs).

export interface ServiceDef {
  name: string;
  port: number;
  url: string | null;
  healthUrl: string | null;
  container: string | null;
  dockerService: string | null;
}

export interface GitPull {
  enabled: boolean;
  repos: string[];
}

export interface PhaseService {
  name: string;
  path: string;
  command: string;
  network: string | null;
}

export interface DockerPhase {
  name: string;
  parallel: boolean;
  waitHealthy: string[];
  healthTimeoutSeconds: number | null;
  services: PhaseService[];
}

export interface Config {
  version: string;
  projectRoot: string;
  projectShare: string | null;
  gitPull: GitPull | null;
  dockerPhases: DockerPhase[];
  services: ServiceDef[];
}

export type ProgressStatus =
  | "started"
  | "ok"
  | "warn"
  | "error"
  | "info"
  | "log";

export interface Progress {
  phase: string;
  service: string | null;
  status: ProgressStatus;
  message: string | null;
}

export interface LogMeta {
  name: string;
  modifiedMs: number;
  sizeBytes: number;
}

export type Health = "up" | "down";

export interface ServiceStatus {
  name: string;
  port: number;
  url: string | null;
  health: Health;
  latencyMs: number | null;
  dockerService: string | null;
}
