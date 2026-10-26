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
  /** (Old per-account level unlocks; every level is open now.) */
  l2?: boolean;
  l3?: boolean;
}

/* ─────────── Levels ─────────── */

export const LEVELS = [
  { n: 1, name: "Lion Temple", blurb: "The original run." },
  { n: 2, name: "Crimson Peak", blurb: "Moving platforms, power-ups, lion abilities and Riser bosses." },
  { n: 3, name: "The Arena", blurb: "A random Riser chases you and throws their moves at the level; every run hits the club's Riser Boss." },
] as const;

/** Lion abilities: active on Levels 2 and 3. */
export const ABILITIES: Record<string, { name: string; text: string }> = {
  stone: { name: "Steady Grip", text: "Grip-fight gold zone is 15% wider." },
  sakura: { name: "Petal Float", text: "Hold to glide: you fall much slower." },
  jade: { name: "Lucky Jade", text: "Half your coins come in pairs, and coins score 25% more." },
  wave: { name: "Wave Rider", text: "The first fall each run washes you back up, no heart lost." },
  crystal: { name: "Frost Grip", text: "Grip needle 30% slower, and your first slipped grip on a rival costs no heart." },
  flame: { name: "Blaze Pin", text: "Pins score 50% more and launch you further." },
  thunder: { name: "Storm Jump", text: "Triple jump." },
  moon: { name: "Moon Shield", text: "Start with a shield that comes back 30 seconds after it breaks." },
  eclipse: { name: "Eclipse Heart", text: "Start with 4 hearts, and every boss you pin gives a heart back." },
};

/** Arena abilities: extra, on top of the Level 2 ability, on Level 3 only. */
export const ABILITIES3: Record<string, { name: string; text: string }> = {
  stone: { name: "Rooted", text: "The boss's Press can't slam your table, and their Hook can't drag you back." },
  sakura: { name: "Petal Veil", text: "King's Move lights-out is half as dark, and thrown chalk can't blind you." },
  jade: { name: "Jade Fortune", text: "Coins push the boss back twice as far." },
  wave: { name: "Undertow", text: "No skidding on wet tables: each one you land on washes the boss back." },
  crystal: { name: "Cold Stare", text: "The boss freezes for 2.5 seconds after every move they throw." },
  flame: { name: "Wildfire", text: "Beast Mode lasts 50% longer." },
  thunder: { name: "Thunderclap", text: "Unleashing Beast Mode pins every rival on screen and blasts the boss back." },
  moon: { name: "One Hand", text: "Double grips need one hand, and finishing grips need 2 good grips, not 3." },
  eclipse: { name: "Blood Moon", text: "The boss chases 25% slower, and your staggers score 50% more." },
};

export type PowerKind = "shield" | "magnet" | "x2";
export const POWERS: Record<PowerKind, { name: string; secs: number; color: string; icon: string }> = {
  shield: { name: "Shield", secs: 0, color: "#7fc8ff", icon: "⛨" },
  magnet: { name: "Magnet", secs: 8, color: "#ff5a5f", icon: "U" },
  x2: { name: "Coins x2", secs: 8, color: "#f2c14e", icon: "x2" },
};

/** A real Riser who shows up as a Level 2 boss. */
export interface Boss {
  id: number;
  name: string;
  photo: string | null;
  /** Cartoon boss art in /pinrun/bosses/<id>.webp, when we have it. */
  art?: string | null;
}

/** Risers with cartoon boss art (square, waist-up, flexing, face in the upper middle). */
export const BOSS_ART = new Set([1, 2, 3, 4, 5, 8]);

/** Signature moves: each boss bends the grip meter in their own way. */
export type MoveKind = "toproll" | "hook" | "hydraulic" | "press" | "side" | "kings" | "fake" | "chain";
export const MOVES: Record<MoveKind, { name: string; tip: string; color: string }> = {
  toproll: { name: "Toproll", tip: "the gold zone rolls along the bar", color: "#ffb347" },
  hook: { name: "Hook", tip: "the needle snaps back without warning", color: "#ff5a5f" },
  hydraulic: { name: "Hydraulic Press", tip: "the needle pumps slow, then surges", color: "#7fc8ff" },
  press: { name: "Press", tip: "the gold zone gets crushed smaller", color: "#ff7a3d" },
  side: { name: "Side Pressure", tip: "the needle drags slow, then whips through", color: "#c79bff" },
  kings: { name: "King's Move", tip: "the gold zone flickers out of sight", color: "#f2c14e" },
  fake: { name: "Fake-Out", tip: "the gold zone jumps when you get close", color: "#7dffb0" },
  chain: { name: "Champion's Chain", tip: "a new move every grip", color: "#ffffff" },
};
/** Who uses what. Risers not listed cycle through the moves by ID. */
export const BOSS_MOVES: Record<number, MoveKind> = {
  1: "toproll", // Harry
  2: "hook", // George
  3: "hydraulic", // Phillip
  4: "press", // Bhavya
  5: "side", // Kelvin
  6: "kings", // Tommy
  7: "fake", // Luie
  8: "chain", // Erick
};
const MOVE_ORDER: MoveKind[] = ["toproll", "hook", "hydraulic", "press", "side", "kings", "fake"];
export const moveOf = (id: number): MoveKind => BOSS_MOVES[id] ?? MOVE_ORDER[(id - 1) % MOVE_ORDER.length];
/** Champion's Chain: the move used on each grip round (0, 1, 2…). */
export const chainMove = (round: number): MoveKind => (["toproll", "hook", "press"] as MoveKind[])[round % 3];
