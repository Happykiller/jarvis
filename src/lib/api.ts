import { invoke } from "@tauri-apps/api/core";

import type { Config, ServiceStatus } from "../types";

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
