/**
 * Katana Draw: a samurai quick-draw ladder. Pay Temple coins to enter, beat Risers one by one
 * (wait for the signal, draw before they do), and cash out whenever you like. Lose a duel and the
 * pot is gone.
 */
export const KATANA_ENTRY = 250;
/** What you can cash out after 1..6 wins (index = wins). */
export const KATANA_PRIZES = [0, 150, 300, 500, 900, 1600, 3000];
/** The ladder, easiest to hardest (Riser IDs); Erick, the champ, is last. */
export const KATANA_ORDER = [1, 3, 5, 4, 2, 8];
/** How fast each rung draws (ms after the signal), before a little random wobble. */
export const KATANA_REACT = [480, 430, 385, 345, 310, 275];
/** From this rung on, opponents feint (a false tell before the real signal). */
export const KATANA_FEINT_FROM = 2;
