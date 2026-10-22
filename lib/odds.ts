/**
 * Supermatch odds. The price on each puller comes from the stake pools (like a tote): the
 * less-backed puller is priced higher. The lion seeds each side with POOL_SEED coins, so odds
 * open at 2.00× and stay sane when one side has no backers.
 *
 * Each bet locks in the price shown at the moment it's placed, and pays stake × those odds if
 * right. The bet then moves the price for the next person (the first bet on a match always
 * gets 2.00×).
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

/** The odds a new bet on `side` locks in: the current price, before the bet moves it. */
export function quoteOdds(side: "a" | "b", p: Pools) {
  return oddsOf(p)[side];
}

/** What a winning stake pays back (stake included) at the given locked odds. */
export const payoutAt = (stake: number, odds: number) => (stake > 0 ? Math.floor(stake * odds + 1e-9) : 0);

export const fmtOdds = (x: number) => `${x.toFixed(2)}×`;
