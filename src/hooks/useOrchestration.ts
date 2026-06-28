import { useCallback, useEffect, useState } from "react";
import { listen } from "@tauri-apps/api/event";

import { startEnvironment } from "../lib/api";
import { speak } from "../lib/tts";
import type { Progress } from "../types";

export interface OrchestrationState {
  running: boolean;
  events: Progress[];
  finished: "ok" | "error" | null;
  start: () => void;
  dismiss: () => void;
}

/** Drives `start_environment` and accumulates its streamed progress events. */
export function useOrchestration(): OrchestrationState {
  const [events, setEvents] = useState<Progress[]>([]);
  const [running, setRunning] = useState(false);
  const [finished, setFinished] = useState<"ok" | "error" | null>(null);

  useEffect(() => {
    const unlisten = listen<Progress>("orchestration", (e) => {
      setEvents((prev) => [...prev, e.payload]);
    });
    return () => {
      void unlisten.then((off) => off());
    };
  }, []);

  const start = useCallback(() => {
    setEvents([]);
    setFinished(null);
    setRunning(true);
    speak("Je demarre l'environnement Galakrond.");

    startEnvironment()
      .then(() => {
        setFinished("ok");
        speak("Environnement Galakrond demarre. Tout est pret.");
      })
      .catch(() => {
        setFinished("error");
        speak("Le demarrage a rencontre une erreur.");
      })
      .finally(() => setRunning(false));
  }, []);

  const dismiss = useCallback(() => {
    setEvents([]);
    setFinished(null);
  }, []);

  return { running, events, finished, start, dismiss };
}
