export const START_ELO = 1000;
export const K_FACTOR = 32;
/** Pullers with fewer matches than this show a provisional rating. */
export const PROVISIONAL_MATCHES = 5;

export function expected(a: number, b: number) {
  return 1 / (1 + 10 ** ((b - a) / 400));
}

export function eloAfter(winner: number, loser: number) {
  const delta = Math.round(K_FACTOR * (1 - expected(winner, loser)));
  return { winner: winner + delta, loser: loser - delta, delta };
}

export const TIERS = [
  { min: 1350, name: "Champion", short: "CHMP" },
  { min: 1250, name: "Elite", short: "ELTE" },
  { min: 1150, name: "Challenger", short: "CHAL" },
  { min: 1050, name: "Contender", short: "CONT" },
  { min: 950, name: "Riser", short: "RISR" },
  { min: -Infinity, name: "Prospect", short: "PROS" },
] as const;

export function tierFor(elo: number) {
  return TIERS.find((t) => elo >= t.min)!;
}
