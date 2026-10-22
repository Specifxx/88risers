import type { RtpLevel } from "./arcade";
import type { PredictionRecord } from "./supermatch";

/** Collectable trophies, all worked out from existing data (nothing to store). */
export interface Achievement {
  id: string;
  name: string;
  how: string;
  icon: string;
}

export const ACHIEVEMENTS: Achievement[] = [
  { id: "early", name: "Early Riser", how: "One of the first 88 members", icon: "🌅" },
  { id: "called", name: "Called It", how: "Get a supermatch pick right", icon: "🎯" },
  { id: "hothand", name: "Hot Hand", how: "3 supermatch calls in a row", icon: "🔥" },
  { id: "oracle", name: "Oracle", how: "80%+ hit rate over 5+ supermatches", icon: "🔮" },
  { id: "underdog", name: "Underdog Whisperer", how: "Win a stake at 2.50× or better", icon: "🐺" },
  { id: "highroller", name: "High Roller", how: "Stake 200+ coins on one supermatch", icon: "💰" },
  { id: "bigstack", name: "Big Stack", how: "Hold 500+ coins", icon: "🪙" },
  { id: "kelvinator", name: "Kelvinator Slayer", how: "Beat the Kelvinator in Race to the Pin", icon: "🦁" },
  { id: "arcade", name: "Full Arcade", how: "Win Race to the Pin on all four levels", icon: "🕹️" },
  { id: "longhaul", name: "Long Haul", how: "Score 5,000+ in Pin Run", icon: "🏃" },
  { id: "collector", name: "Collector", how: "Own all three card frames", icon: "🖼️" },
  { id: "lucky", name: "Lucky Ticket", how: "Win a giveaway draw", icon: "🎟️" },
  { id: "lift", name: "Lift Complete", how: "Hit the Chalk target in a season", icon: "🏋️" },
];

export interface AchievementInput {
  memberNo: number;
  coins: number;
  rec: PredictionRecord;
  pinRun: number | null;
  rtp: Partial<Record<RtpLevel, number>>;
  /** Reward-store items owned (ids), and whether any giveaway entry won. */
  items: string[];
  wonGiveaway: boolean;
  liftDone: boolean;
}

export function earnedAchievements(x: AchievementInput): Set<string> {
  const settled = x.rec.history.filter((h) => h.settled_at);
  const won = settled.filter((h) => h.pick_id === h.winner_id);
  const has = (id: string, ok: boolean) => (ok ? [id] : []);
  return new Set([
    ...has("early", x.memberNo <= 88),
    ...has("called", won.length > 0),
    ...has("hothand", x.rec.bestStreak >= 3),
    ...has("oracle", x.rec.settled >= 5 && (x.rec.rate ?? 0) >= 80),
    ...has("underdog", won.some((h) => h.stake > 0 && (h.odds ?? 0) >= 2.5)),
    ...has("highroller", x.rec.history.some((h) => h.stake >= 200)),
    ...has("bigstack", x.coins >= 500),
    ...has("kelvinator", !!x.rtp.kelvinator),
    ...has("arcade", (["rookie", "club", "elite", "kelvinator"] as const).every((l) => !!x.rtp[l])),
    ...has("longhaul", (x.pinRun ?? 0) >= 5000),
    ...has("collector", ["frame-gold", "frame-ink", "frame-holo"].every((f) => x.items.includes(f))),
    ...has("lucky", x.wonGiveaway),
    ...has("lift", x.liftDone),
  ]);
}
