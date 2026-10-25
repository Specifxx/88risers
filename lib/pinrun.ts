/**
 * Pin Run's Lion Temple. Coins grabbed during runs are saved as Temple coins (kept apart from
 * 88Risers coins, which stay capped at the daily game bonus) and spent on lion skins.
 */
export interface Skin {
  id: string;
  name: string;
  price: number;
  blurb: string;
  /** Running legs: [fill, far-side fill, rim highlight], matched to the lion's own front leg. */
  legs: [string, string, string];
  /** The run cycle in /pinrun/anim/<id>.webp: a strip of `frames` frames, each `w` px wide. */
  anim: { frames: number; w: number };
}

/** Run-cycle strips are 201px tall (2x the in-game size); feet on the bottom edge at x≈230. */
export const ANIM = { h: 201, ax: 230, scale: 0.5 };

export const SKINS: Skin[] = [
  {
    id: "stone",
    name: "Stone Guardian",
    price: 0,
    blurb: "The original. Carved gold stone, never blinks.",
    legs: ["#8a6c4c", "#4a3a29", "#d5b67a"],
    anim: { frames: 12, w: 409 },
  },
  {
    id: "sakura",
    name: "Sakura",
    price: 600,
    blurb: "Cherry blossom season at the table.",
    legs: ["#c9b2a4", "#6e5f57", "#f3c4d2"],
    anim: { frames: 11, w: 409 },
  },
  {
    id: "jade",
    name: "Jade",
    price: 900,
    blurb: "Polished jade with golden clouds.",
    legs: ["#5f7a3c", "#2f3d1d", "#d1b25a"],
    anim: { frames: 12, w: 409 },
  },
  {
    id: "wave",
    name: "Great Wave",
    price: 1200,
    blurb: "Rides in on the tide.",
    legs: ["#5c5c5a", "#2c2c2b", "#9ec4e8"],
    anim: { frames: 13, w: 409 },
  },
  {
    id: "crystal",
    name: "Ice Crystal",
    price: 1500,
    blurb: "Cold blooded. Shatters grips.",
    legs: ["#5f92b4", "#2c4a5e", "#9fe0ff"],
    anim: { frames: 12, w: 410 },
  },
  {
    id: "flame",
    name: "Inferno",
    price: 2000,
    blurb: "Wreathed in fire. Hot hand, hotter hook.",
    legs: ["#995f47", "#4d2f22", "#ff7a45"],
    anim: { frames: 12, w: 409 },
  },
  {
    id: "thunder",
    name: "Thunder",
    price: 2500,
    blurb: "Storm clouds and lightning off every pin.",
    legs: ["#7d5d3f", "#3f2f20", "#f2c14e"],
    anim: { frames: 11, w: 409 },
  },
  {
    id: "moon",
    name: "Moonlight",
    price: 3000,
    blurb: "A violet spirit under the full moon.",
    legs: ["#5c3e78", "#2e1f3c", "#b994ff"],
    anim: { frames: 12, w: 410 },
  },
  {
    id: "eclipse",
    name: "Eclipse",
    price: 4000,
    blurb: "Blood moon, falling maple. The rarest lion.",
    legs: ["#6c4231", "#372118", "#ff8a4a"],
    anim: { frames: 12, w: 410 },
  },
];

export const DEFAULT_SKIN = "stone";
export const skinById = (id: string) => SKINS.find((s) => s.id === id) ?? null;

/**
 * Each coin adds at least 10 points; with Coin x2 and Lucky Jade a coin can bank up to 3, so a real
 * run never banks more than ~score/3. Anything far above that is faked.
 */
export const plausibleCoins = (score: number) => 30 + Math.floor(score / 3);

export interface Wallet {
  coins: number;
  skin: string;
  owned: string[];
}

/* ─────────── Levels ─────────── */

/** Score on Level 1 that unlocks Level 2. */
export const LEVEL2_UNLOCK = 20000;

export const LEVELS = [
  { n: 1, name: "Lion Temple", blurb: "The original run." },
  { n: 2, name: "Crimson Peak", blurb: "Moving platforms, power-ups, lion abilities and Riser bosses." },
] as const;

/** Lion abilities: active on Level 2. */
export const ABILITIES: Record<string, { name: string; text: string }> = {
  stone: { name: "Steady Grip", text: "Grip-fight gold zone is 25% wider." },
  sakura: { name: "Petal Float", text: "Hold to glide: you fall much slower." },
  jade: { name: "Lucky Jade", text: "Half your coins come in pairs." },
  wave: { name: "Wave Rider", text: "The first fall each run washes you back up, no heart lost." },
  crystal: { name: "Frost Grip", text: "Grip-fight needle moves 25% slower." },
  flame: { name: "Blaze Pin", text: "Pins score 50% more and launch you further." },
  thunder: { name: "Storm Jump", text: "Triple jump." },
  moon: { name: "Moon Shield", text: "Start every run with a shield." },
  eclipse: { name: "Eclipse Heart", text: "Start with 4 hearts." },
};

export type PowerKind = "shield" | "magnet" | "x2" | "slow";
export const POWERS: Record<PowerKind, { name: string; secs: number; color: string; icon: string }> = {
  shield: { name: "Shield", secs: 0, color: "#7fc8ff", icon: "⛨" },
  magnet: { name: "Magnet", secs: 8, color: "#ff5a5f", icon: "U" },
  x2: { name: "Coins x2", secs: 8, color: "#f2c14e", icon: "x2" },
  slow: { name: "Slow time", secs: 5, color: "#9fe0ff", icon: "⧗" },
};

/** A real Riser who shows up as a Level 2 boss. */
export interface Boss {
  id: number;
  name: string;
  photo: string | null;
}
