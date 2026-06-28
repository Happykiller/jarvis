import { useCallback, useEffect, useRef, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";

import { checkServices, loadConfig, restartService } from "./lib/api";
import { speak } from "./lib/tts";
import { useOrchestration } from "./hooks/useOrchestration";
import { ServiceCard } from "./components/ServiceCard";
import { ProgressPanel } from "./components/ProgressPanel";
import type { Config, ServiceStatus } from "./types";

const POLL_MS = 4000;
const USER_NAME = "Fabrice";

function App() {
  const [config, setConfig] = useState<Config | null>(null);
  const [statuses, setStatuses] = useState<ServiceStatus[]>([]);
  const [error, setError] = useState<string | null>(null);
  const greeted = useRef(false);
  const orchestration = useOrchestration();

  const refresh = useCallback(async () => {
    try {
      const next = await checkServices();
      setStatuses(next);
      setError(null);

      // Greet once, after the first probe, announcing how many services are up.
      if (!greeted.current) {
        greeted.current = true;
        const up = next.filter((s) => s.health === "up").length;
        speak(
          up === 0
            ? `Bonjour ${USER_NAME}. L'environnement Galakrond est encore endormi.`
            : `Bonjour ${USER_NAME}. ${up} service${up > 1 ? "s" : ""} sur ${next.length} sont en ligne.`,
        );
      }
    } catch (e) {
      setError(String(e));
    }
  }, []);

  useEffect(() => {
    loadConfig().then(setConfig).catch((e) => setError(String(e)));
    void refresh();
    const id = setInterval(refresh, POLL_MS);
    return () => clearInterval(id);
  }, [refresh]);

  const handleRestart = useCallback(
    async (name: string) => {
      await restartService(name);
      void refresh();
    },
    [refresh],
  );

  const upCount = statuses.filter((s) => s.health === "up").length;
  const total = statuses.length;
  const allUp = total > 0 && upCount === total;

  return (
    <main className="mx-auto flex min-h-full max-w-5xl flex-col gap-8 px-8 py-10">
      {/* Header */}
      <header className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <img
            src="/jarvis-icon.png"
            alt="Jarvis"
            className="h-12 w-12 rounded-2xl"
          />
          <div>
            <h1 className="text-2xl font-bold tracking-tight">Jarvis</h1>
            <p className="text-sm text-slate-400">
              Galakrond launcher{config ? ` - v${config.version}` : ""}
            </p>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <div
            className={[
              "rounded-full px-4 py-1.5 text-sm font-medium",
              allUp
                ? "bg-jarvis-up/15 text-jarvis-up"
                : "bg-white/5 text-slate-300",
            ].join(" ")}
          >
            {total > 0 ? `${upCount}/${total} en ligne` : "Sondage..."}
          </div>
          <button
            type="button"
            onClick={() => void refresh()}
            className="rounded-full border border-white/10 px-4 py-1.5 text-sm text-slate-300 transition-colors hover:border-jarvis-accent/50 hover:text-white"
          >
            Rafraichir
          </button>
          <button
            type="button"
            onClick={orchestration.start}
            disabled={orchestration.running}
            className="rounded-full bg-jarvis-accent px-5 py-1.5 text-sm font-semibold text-jarvis-bg shadow-lg shadow-jarvis-accent/20 transition-transform hover:scale-105 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {orchestration.running ? "Demarrage..." : "Demarrer l'environnement"}
          </button>
        </div>
      </header>

      {error && (
        <div className="rounded-xl border border-jarvis-down/30 bg-jarvis-down/10 px-4 py-3 text-sm text-red-300">
          {error}
        </div>
      )}

      {/* Services grid */}
      <section>
        <h2 className="mb-4 text-xs font-semibold uppercase tracking-widest text-slate-500">
          Services
        </h2>
        <motion.div
          layout
          className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4"
        >
          <AnimatePresence>
            {statuses.map((s) => (
              <ServiceCard key={s.name} status={s} onRestart={handleRestart} />
            ))}
          </AnimatePresence>
        </motion.div>

        {total === 0 && !error && (
          <div className="rounded-2xl border border-white/5 bg-jarvis-panel/40 px-6 py-12 text-center text-slate-500">
            Sondage des services...
          </div>
        )}
      </section>

      <footer className="mt-auto text-center text-xs text-slate-600">
        Jarvis - propulse par Tauri + React.
      </footer>

      <ProgressPanel
        open={orchestration.running || orchestration.events.length > 0}
        running={orchestration.running}
        finished={orchestration.finished}
        events={orchestration.events}
        onClose={orchestration.dismiss}
      />
    </main>
  );
}

export default App;
