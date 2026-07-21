import { useCallback, useEffect, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";

import { listLogs, openLogsDir, readLog } from "../lib/api";
import type { LogMeta } from "../types";

interface Props {
  open: boolean;
  onClose: () => void;
}

function formatDate(ms: number): string {
  if (!ms) return "date inconnue";
  return new Date(ms).toLocaleString("fr-FR", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
}

function formatSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} o`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} Ko`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} Mo`;
}

/** Colors a log line by its [STATUS] tag for quick scanning. */
function lineClass(line: string): string {
  if (line.startsWith("====")) return "text-jarvis-accent";
  if (line.includes("[ERROR]")) return "text-jarvis-down";
  if (line.includes("[WARN]")) return "text-amber-400";
  if (line.includes("[OK]")) return "text-jarvis-up";
  if (line.includes("[INFO]")) return "text-slate-300";
  return "text-slate-500";
}

export function LogsPanel({ open, onClose }: Props) {
  const [logs, setLogs] = useState<LogMeta[]>([]);
  const [selected, setSelected] = useState<string | null>(null);
  const [content, setContent] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const openLog = useCallback(async (name: string) => {
    setSelected(name);
    setLoading(true);
    setError(null);
    try {
      setContent(await readLog(name));
    } catch (e) {
      setError(String(e));
      setContent("");
    } finally {
      setLoading(false);
    }
  }, []);

  const refresh = useCallback(async () => {
    try {
      const list = await listLogs();
      setLogs(list);
      setError(null);
      if (list.length > 0) {
        // Keep the current selection if it still exists, else pick the newest.
        const keep = list.find((l) => l.name === selected)?.name;
        void openLog(keep ?? list[0].name);
      } else {
        setSelected(null);
        setContent("");
      }
    } catch (e) {
      setError(String(e));
    }
  }, [openLog, selected]);

  // Load the list each time the panel opens.
  useEffect(() => {
    if (open) void refresh();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  return (
    <AnimatePresence>
      {open && (
        <>
          <motion.div
            className="fixed inset-0 z-30 bg-black/60 backdrop-blur-sm"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
          />
          <motion.div
            className="fixed inset-0 z-40 grid place-items-center p-6"
            initial={{ opacity: 0, scale: 0.98 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.98 }}
            transition={{ type: "spring", stiffness: 320, damping: 32 }}
          >
            <div
              className="flex h-[80vh] w-full max-w-5xl overflow-hidden rounded-2xl border border-white/10 bg-jarvis-panel/95 shadow-2xl backdrop-blur"
              onClick={(e) => e.stopPropagation()}
            >
              {/* Runs list */}
              <aside className="flex w-64 shrink-0 flex-col border-r border-white/10">
                <div className="flex items-center justify-between border-b border-white/10 px-4 py-3">
                  <h2 className="text-sm font-semibold">Historique</h2>
                  <button
                    type="button"
                    onClick={() => void refresh()}
                    className="rounded-md px-2 py-1 text-xs text-slate-400 transition-colors hover:text-white"
                  >
                    Rafraichir
                  </button>
                </div>
                <div className="flex-1 overflow-y-auto p-2">
                  {logs.length === 0 && (
                    <p className="px-2 py-6 text-center text-xs text-slate-500">
                      Aucun log pour l'instant.
                    </p>
                  )}
                  {logs.map((l) => (
                    <button
                      key={l.name}
                      type="button"
                      onClick={() => void openLog(l.name)}
                      className={[
                        "mb-1 w-full rounded-lg px-3 py-2 text-left transition-colors",
                        l.name === selected
                          ? "bg-jarvis-accent/15 text-white"
                          : "text-slate-300 hover:bg-white/5",
                      ].join(" ")}
                    >
                      <span className="block truncate text-xs font-medium">
                        {formatDate(l.modifiedMs)}
                      </span>
                      <span className="block truncate text-[10px] text-slate-500">
                        {formatSize(l.sizeBytes)}
                      </span>
                    </button>
                  ))}
                </div>
              </aside>

              {/* Content */}
              <section className="flex min-w-0 flex-1 flex-col">
                <header className="flex items-center justify-between border-b border-white/10 px-5 py-3">
                  <h3 className="truncate text-sm font-mono text-slate-300">
                    {selected ?? "Logs"}
                  </h3>
                  <div className="flex items-center gap-2">
                    <button
                      type="button"
                      onClick={() => void openLogsDir()}
                      className="rounded-md border border-white/10 px-3 py-1 text-xs text-slate-300 transition-colors hover:border-jarvis-accent/50 hover:text-white"
                    >
                      Ouvrir le dossier
                    </button>
                    <button
                      type="button"
                      onClick={onClose}
                      className="rounded-md px-2 py-1 text-slate-400 transition-colors hover:text-white"
                    >
                      Fermer
                    </button>
                  </div>
                </header>
                <div className="flex-1 overflow-auto bg-black/20 px-5 py-4">
                  {error && (
                    <p className="text-sm text-red-300">{error}</p>
                  )}
                  {loading && !content && (
                    <p className="text-sm text-slate-500">Chargement...</p>
                  )}
                  {!loading && !error && content && (
                    <pre className="whitespace-pre-wrap break-words font-mono text-[11px] leading-relaxed">
                      {content.split("\n").map((line, i) => (
                        <div key={i} className={lineClass(line)}>
                          {line || " "}
                        </div>
                      ))}
                    </pre>
                  )}
                  {!loading && !error && !content && logs.length > 0 && (
                    <p className="text-sm text-slate-500">Fichier vide.</p>
                  )}
                </div>
              </section>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
