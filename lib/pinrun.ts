/**
 * Pin Run's Lion Temple. Coins grabbed during runs are saved as Temple coins (kept apart from
 * 88Risers coins, which stay capped at the daily game bonus) and spent on lion skins.
 */
export interface Skin {
  id: string;
  name: string;
  price: number;
  blurb: string;
}

export const SKINS: Skin[] = [
  { id: "stone", name: "Stone Guardian", price: 0, blurb: "The original. Carved gold stone, never blinks." },
  { id: "sakura", name: "Sakura", price: 60, blurb: "Cherry blossom season at the table." },
  { id: "jade", name: "Jade", price: 90, blurb: "Polished jade with golden clouds." },
  { id: "wave", name: "Great Wave", price: 120, blurb: "Rides in on the tide." },
  { id: "crystal", name: "Ice Crystal", price: 150, blurb: "Cold blooded. Shatters grips." },
  { id: "flame", name: "Inferno", price: 200, blurb: "Wreathed in fire. Hot hand, hotter hook." },
  { id: "thunder", name: "Thunder", price: 250, blurb: "Storm clouds and lightning off every pin." },
  { id: "moon", name: "Moonlight", price: 300, blurb: "A violet spirit under the full moon." },
  { id: "eclipse", name: "Eclipse", price: 400, blurb: "Blood moon, falling maple. The rarest lion." },
];

export const DEFAULT_SKIN = "stone";
export const skinById = (id: string) => SKINS.find((s) => s.id === id) ?? null;

/** Most coins one run can bank, and per Sydney day: generous, but stops faked scores. */
export const RUN_COIN_CAP = 200;
export const DAY_COIN_CAP = 1500;
/** Real runs earn roughly one coin per 15 points; anything far above that isn't a real run. */
export const plausibleCoins = (score: number) => 10 + Math.floor(score / 8);

export interface Wallet {
  coins: number;
  skin: string;
  owned: string[];
}
