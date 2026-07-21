import { invoke } from "@tauri-apps/api/core";

import type { Config, LogMeta, ServiceStatus } from "../types";

/** Loads the parsed jarvis.config.json from the Rust backend. */
export function loadConfig(): Promise<Config> {
  return invoke<Config>("load_config");
}

/** Probes every configured service and returns their live status. */
export function checkServices(): Promise<ServiceStatus[]> {
  return invoke<ServiceStatus[]>("check_services");
}

/** Boots the Galakrond environment; progress streams via the "orchestration" event. */
export function startEnvironment(): Promise<void> {
  return invoke<void>("start_environment");
}

/** Restarts a single service by name; progress streams via "orchestration". */
export function restartService(name: string): Promise<void> {
  return invoke<void>("restart_service", { name });
}

/** Lists the persisted run logs, newest first. */
export function listLogs(): Promise<LogMeta[]> {
  return invoke<LogMeta[]>("list_logs");
}

/** Reads one run log by file name. */
export function readLog(name: string): Promise<string> {
  return invoke<string>("read_log", { name });
}

/** Reveals the log directory in the OS file explorer. */
export function openLogsDir(): Promise<void> {
  return invoke<void>("open_logs_dir");
}
