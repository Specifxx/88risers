/**
 * Supermatch odds. The price on each puller comes from the stake pools (like a tote): the
 * less-backed puller is priced higher. The lion seeds each side with POOL_SEED coins, so odds
 * open at 2.00× and stay sane when one side has no backers.
 *
 * Each bet locks in the odds at the moment it's placed (counting its own stake), and pays
 * stake × locked odds if right. Later bets move the price for everyone after, not before.
 * Shared by the server (locking, settling) and the browser (live estimates).
 */
export const POOL_SEED = 100;

export interface Pools {
  a: number;
  b: number;
}

/** Odds are quoted and locked to 2 decimal places, so what you see is what you get. */
const round2 = (x: number) => Math.round(x * 100) / 100;

/** Current decimal odds: coins returned per coin staked, stake included. */
export function oddsOf(p: Pools) {
  const A = p.a + POOL_SEED;
  const B = p.b + POOL_SEED;
  return { a: round2((A + B) / A), b: round2((A + B) / B) };
}

/** The odds a new bet of `stake` on `side` locks in (your own coins shift the price). */
export function quoteOdds(stake: number, side: "a" | "b", p: Pools) {
  return oddsOf({ a: p.a + (side === "a" ? stake : 0), b: p.b + (side === "b" ? stake : 0) })[side];
}

/** What a winning stake pays back (stake included) at the given locked odds. */
export const payoutAt = (stake: number, odds: number) => (stake > 0 ? Math.floor(stake * odds + 1e-9) : 0);

export const fmtOdds = (x: number) => `${x.toFixed(2)}×`;
