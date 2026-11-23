/** Client-safe Rhodes Open settings (no database imports). */
/** Rhodes Open 2027: the club's first open tournament. Still a preliminary draft. */
export const OPEN = {
  slug: "rhodes-open-2027",
  title: "Rhodes Open 2027",
  date: "Sunday 4 April 2027",
  venue: "Rhodes Amphitheatre",
  classes: ["-75kg", "-85kg", "-95kg", "-110kg", "+110kg"] as const,
  /** Weigh-ins happen at the venue on the day. */
  weighIns: "On the day, at the venue",
};
export type OpenClass = (typeof OPEN.classes)[number];
export type OpenArms = "right" | "left" | "both";
export const ARMS_LABEL: Record<OpenArms, string> = { right: "Right arm", left: "Left arm", both: "Both arms" };
export const classLabel = (c: string) => c.replace("-", "−").replace("kg", " kg");
