// Thin wrapper over the Web Speech API so the rest of the app speaks in one
// line. Prefers a French voice when one is installed; silently no-ops when the
// platform has no speech synthesis.

let cachedVoice: SpeechSynthesisVoice | null | undefined;

function pickVoice(): SpeechSynthesisVoice | null {
  if (cachedVoice !== undefined) return cachedVoice;
  const voices = window.speechSynthesis?.getVoices() ?? [];
  cachedVoice =
    voices.find((v) => v.lang.toLowerCase().startsWith("fr")) ?? voices[0] ?? null;
  return cachedVoice;
}

/** Speaks the given text aloud (French by default). */
export function speak(text: string, lang = "fr-FR"): void {
  const synth = window.speechSynthesis;
  if (!synth) return;

  const utter = new SpeechSynthesisUtterance(text);
  utter.lang = lang;
  utter.rate = 1;
  utter.pitch = 1;
  const voice = pickVoice();
  if (voice) utter.voice = voice;

  synth.cancel();
  synth.speak(utter);
}

// Voices load asynchronously on some platforms; reset the cache when they
// arrive so the first greeting can still pick a French voice.
if (typeof window !== "undefined" && window.speechSynthesis) {
  window.speechSynthesis.onvoiceschanged = () => {
    cachedVoice = undefined;
  };
}
