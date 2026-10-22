/**
 * Supermatch odds, pool style (like a tote): every coin staked on either side goes into one
 * pool, and the winning side splits it in proportion to their stakes. The less-backed puller
 * pays more. The lion seeds each side with POOL_SEED coins, so odds open at 2.00× and stay
 * sane when one side has no backers. Odds are live until voting closes; payouts use the
 * final pool. Shared by the server (settling) and the browser (live estimates).
 */
export const POOL_SEED = 100;

export interface Pools {
  a: number;
  b: number;
}

/** Decimal odds: coins returned per coin staked, stake included. */
export function oddsOf(p: Pools) {
  const A = p.a + POOL_SEED;
  const B = p.b + POOL_SEED;
  return { a: (A + B) / A, b: (A + B) / B };
}

/** What a winning stake pays back (stake included), from the pools at settlement. */
export function payoutFor(stake: number, side: "a" | "b", p: Pools) {
  if (stake <= 0) return 0;
  return Math.floor(stake * oddsOf(p)[side]);
}

/** Estimated return if you add `stake` on `side` now (your own coins shift the odds). */
export function estimateReturn(stake: number, side: "a" | "b", p: Pools) {
  return payoutFor(stake, side, { a: p.a + (side === "a" ? stake : 0), b: p.b + (side === "b" ? stake : 0) });
}

export const fmtOdds = (x: number) => `${x.toFixed(2)}×`;
