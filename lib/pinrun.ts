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
  /** Level 2 unlocked by an organiser (as well as by scoring 5,000). */
  l2?: boolean;
  /** Level 3 unlocked by an organiser (as well as by scoring 5,000 on Level 2). */
  l3?: boolean;
  /** Run boosts in stock, by id. */
  boosts?: Record<string, number>;
  /** Ability upgrade tier (0-3) per lion. */
  ups?: Record<string, number>;
  /** Lions gilded gold. */
  gold?: string[];
}

/* ─────────── Coin sinks: run boosts, ability upgrades, golden lions ─────────── */

export type BoostId = "revive" | "magnet" | "heart" | "shield" | "hype";
export const BOOSTS: { id: BoostId; name: string; price: number; icon: string; text: string; l3?: boolean }[] = [
  { id: "revive", name: "Second Wind", price: 300, icon: "♥︎", text: "Out of hearts? Get back up once with 1 heart." },
  { id: "magnet", name: "Coin Magnet", price: 150, icon: "U", text: "Pulls coins in for the first 20 seconds of the run." },
  { id: "heart", name: "Extra Heart", price: 250, icon: "+", text: "Start with one more heart." },
  { id: "shield", name: "Starting Shield", price: 250, icon: "⛨", text: "Start with a shield that soaks one hit." },
  { id: "hype", name: "Hype Drink", price: 200, icon: "🔥", text: "Level 3 only: start with full hype, ready for Beast Mode.", l3: true },
];
export const BOOST_MAX = 20;
export const boostById = (id: string) => BOOSTS.find((b) => b.id === id) ?? null;

/** Cost of ability upgrade tiers 1, 2 and 3 (each lion upgrades both its Lv.2 and Lv.3 ability). */
export const UPGRADE_COSTS = [1000, 2500, 5000];
export const GOLD_PRICE = 10000;

/**
 * The numbers each ability uses at upgrade tiers 0-3. Abilities that are on/off (Triple Jump,
 * Rooted...) upgrade the lion's other ability.
 */
export const TIER = {
  stoneZone: [1.15, 1.2, 1.25, 1.3],
  sakuraFall: [230, 200, 170, 140],
  jadeScore: [1.25, 1.35, 1.45, 1.55],
  jadePair: [0.5, 0.55, 0.6, 0.65],
  waveSaves: [1, 2, 2, 3],
  crystalNeedle: [0.7, 0.65, 0.6, 0.55],
  crystalStare: [2.5, 3, 3.5, 4],
  flamePin: [1.5, 1.65, 1.8, 2],
  flameBeast: [9, 10, 11, 12],
  thunderPush: [0.3, 0.38, 0.46, 0.55],
  moonRegen: [30, 25, 20, 15],
  eclipseSlow: [0.75, 0.7, 0.65, 0.6],
};
const pct = (x: number) => `${Math.round(x * 100)}%`;
/** What an upgrade tier gives, in words (for the Temple). */
export function upgradeText(skin: string, tier: number): string {
  const t = Math.max(0, Math.min(3, tier));
  switch (skin) {
    case "stone":
      return `Gold zone ${pct(TIER.stoneZone[t] - 1)} wider`;
    case "sakura":
      return t ? `Glide ${pct(1 - TIER.sakuraFall[t] / TIER.sakuraFall[0])} floatier` : "Standard glide";
    case "jade":
      return `Coins score +${pct(TIER.jadeScore[t] - 1)}, pairs ${pct(TIER.jadePair[t])} of the time`;
    case "wave":
      return `${TIER.waveSaves[t]} free fall${TIER.waveSaves[t] > 1 ? "s" : ""} per run`;
    case "crystal":
      return `Needle ${pct(1 - TIER.crystalNeedle[t])} slower, Cold Stare ${TIER.crystalStare[t]}s`;
    case "flame":
      return `Pins +${pct(TIER.flamePin[t] - 1)}, Beast Mode ${TIER.flameBeast[t]}s`;
    case "thunder":
      return `Thunderclap pushes the boss back ${pct(TIER.thunderPush[t])}`;
    case "moon":
      return `Shield returns after ${TIER.moonRegen[t]}s`;
    case "eclipse":
      return `Boss chases ${pct(1 - TIER.eclipseSlow[t])} slower`;
    default:
      return "";
  }
}

/* ─────────── Levels ─────────── */

/** Score on Level 1 that unlocks Level 2. */
export const LEVEL2_UNLOCK = 5000;
/** Score on Level 2 that unlocks Level 3. */
export const LEVEL3_UNLOCK = 5000;

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
  jade: { name: "Jade Fortune", text: "Coins push the boss back twice as far and do double raid damage." },
  wave: { name: "Undertow", text: "No skidding on wet tables: each one you land on washes the boss back." },
  crystal: { name: "Cold Stare", text: "The boss freezes for 2.5 seconds after every move they throw." },
  flame: { name: "Wildfire", text: "Beast Mode lasts 50% longer and does double raid damage." },
  thunder: { name: "Thunderclap", text: "Unleashing Beast Mode pins every rival on screen and blasts the boss back." },
  moon: { name: "One Hand", text: "Double grips need one hand, and finishing grips need 2 good grips, not 3." },
  eclipse: { name: "Blood Moon", text: "The boss chases 25% slower, and your staggers do 50% more raid damage." },
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

/* ─────────── Club Raid (Level 3) ─────────── */

/** Health of each Riser Boss; the whole club's Level 3 runs chip at it. */
export const RAID_HP = 40000;
/** Temple coins for everyone who hit a raid boss when it falls, and a bonus for the top hitter. */
export const RAID_REWARD = 250;
export const RAID_TOP_BONUS = 250;

/** The Riser Boss: one health pool the whole club chips at on Level 3. */
export interface Raid {
  id: number;
  hp: number;
  hpMax: number;
}

/** Raid damage can't run far ahead of a run's score (it's earned the same way). */
export const plausibleDamage = (score: number) => 200 + Math.floor(score * 0.8);
