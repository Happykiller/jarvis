import { useEffect, useRef } from "react";
import { AnimatePresence, motion } from "framer-motion";

import type { Progress, ProgressStatus } from "../types";

interface Props {
  open: boolean;
  running: boolean;
  finished: "ok" | "error" | null;
  events: Progress[];
  onClose: () => void;
}

const ICON: Record<ProgressStatus, string> = {
  started: "...",
  ok: "OK",
  warn: "!",
  error: "X",
  info: "i",
  log: "",
};

const COLOR: Record<ProgressStatus, string> = {
  started: "bg-slate-600 text-slate-200",
  ok: "bg-jarvis-up/20 text-jarvis-up",
  warn: "bg-amber-500/20 text-amber-400",
  error: "bg-jarvis-down/20 text-jarvis-down",
  info: "bg-jarvis-accent/20 text-jarvis-accent",
  log: "",
};

function label(e: Progress): string {
  if (e.service) return `${e.phase} / ${e.service}`;
  return e.phase;
}

export function ProgressPanel({ open, running, finished, events, onClose }: Props) {
  const endRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth", block: "end" });
  }, [events.length]);

  return (
    <AnimatePresence>
      {open && (
        <>
          <motion.div
            className="fixed inset-0 z-10 bg-black/50 backdrop-blur-sm"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={running ? undefined : onClose}
          />
          <motion.aside
            className="fixed right-0 top-0 z-20 flex h-full w-[420px] flex-col border-l border-white/10 bg-jarvis-panel/95 shadow-2xl backdrop-blur"
            initial={{ x: 440 }}
            animate={{ x: 0 }}
            exit={{ x: 440 }}
            transition={{ type: "spring", stiffness: 320, damping: 32 }}
          >
            <header className="flex items-center justify-between border-b border-white/10 px-5 py-4">
              <div className="flex items-center gap-3">
                {running && (
                  <span className="h-3 w-3 animate-spin rounded-full border-2 border-jarvis-accent border-t-transparent" />
                )}
                <h2 className="text-sm font-semibold">
                  {running
                    ? "Demarrage en cours..."
                    : finished === "ok"
                      ? "Environnement demarre"
                      : finished === "error"
                        ? "Demarrage interrompu"
                        : "Demarrage"}
                </h2>
              </div>
              <button
                type="button"
                onClick={onClose}
                disabled={running}
                className="rounded-md px-2 py-1 text-slate-400 transition-colors enabled:hover:text-white disabled:opacity-30"
              >
                Fermer
              </button>
            </header>

            <div className="flex-1 space-y-1 overflow-y-auto px-4 py-4">
              {events.map((e, i) =>
                e.status === "log" ? (
                  <p
                    key={i}
                    className="truncate pl-11 font-mono text-[11px] leading-relaxed text-slate-500"
                    title={e.message ?? ""}
                  >
                    {e.message}
                  </p>
                ) : (
                  <div key={i} className="flex items-start gap-3 rounded-lg px-2 py-1.5">
                    <span
                      className={[
                        "mt-0.5 grid h-6 w-6 shrink-0 place-items-center rounded-md text-[10px] font-bold",
                        COLOR[e.status],
                      ].join(" ")}
                    >
                      {ICON[e.status]}
                    </span>
                    <div className="min-w-0">
                      <p className="truncate text-sm capitalize text-slate-200">
                        {label(e)}
                      </p>
                      {e.message && (
                        <p className="text-xs text-slate-500">{e.message}</p>
                      )}
                    </div>
                  </div>
                ),
              )}
              <div ref={endRef} />
            </div>
          </motion.aside>
        </>
      )}
    </AnimatePresence>
  );
}
