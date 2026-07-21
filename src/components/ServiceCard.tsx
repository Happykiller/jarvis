import { useState } from "react";
import { motion } from "framer-motion";
import { openUrl } from "@tauri-apps/plugin-opener";

import type { ServiceStatus } from "../types";

interface Props {
  status: ServiceStatus;
  onRestart: (name: string) => Promise<void>;
}

export function ServiceCard({ status, onRestart }: Props) {
  const up = status.health === "up";
  const [restarting, setRestarting] = useState(false);

  const open = () => {
    if (status.url) void openUrl(status.url);
  };

  const restart = async () => {
    if (restarting) return;
    setRestarting(true);
    try {
      await onRestart(status.name);
    } finally {
      setRestarting(false);
    }
  };

  return (
    <motion.div
      whileHover={{ y: -3 }}
      layout
      className={[
        "group relative flex flex-col gap-3 rounded-2xl border p-4 transition-colors",
        "bg-jarvis-panel/70 backdrop-blur",
        up ? "border-jarvis-up/30" : "border-white/5",
      ].join(" ")}
    >
      <div className="flex items-center justify-between">
        <span className="text-base font-semibold capitalize">{status.name}</span>
        <span className="flex items-center gap-2 text-xs uppercase tracking-wide">
          <span
            className={[
              "h-2.5 w-2.5 rounded-full",
              up ? "bg-jarvis-up jarvis-pulse" : "bg-jarvis-down",
            ].join(" ")}
          />
          {up ? "online" : "offline"}
        </span>
      </div>

      <div className="flex items-end justify-between">
        <button
          type="button"
          onClick={open}
          disabled={!status.url}
          className={[
            "font-mono text-sm text-slate-400",
            status.url ? "cursor-pointer hover:text-jarvis-accent" : "cursor-default",
          ].join(" ")}
        >
          {status.port > 0 ? `:${status.port}` : "docker"}
        </button>

        <div className="flex items-center gap-2">
          <span className="text-xs text-slate-500">
            {status.latencyMs != null ? `${status.latencyMs} ms` : "--"}
          </span>
          {status.dockerService && (
            <button
              type="button"
              onClick={restart}
              disabled={restarting}
              title={`Redemarrer ${status.dockerService}`}
              className="grid h-6 w-6 place-items-center rounded-md border border-white/10 text-xs text-slate-400 transition-colors hover:border-jarvis-accent/50 hover:text-white disabled:opacity-40"
            >
              <span className={restarting ? "inline-block animate-spin" : ""}>
                {restarting ? "◌" : "↻"}
              </span>
            </button>
          )}
        </div>
      </div>
    </motion.div>
  );
}
