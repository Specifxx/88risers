/** Ask the corner lion mascot (MerchLion) to react. Client-side only. */
export type LionMood = "roar" | "flex" | "cheer";
export function lionSays(mood: LionMood, text: string) {
  if (typeof window === "undefined") return;
  window.dispatchEvent(new CustomEvent("88r:lion", { detail: { mood, text } }));
}
