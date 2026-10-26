import "server-only";
import { randomBytes } from "node:crypto";
import type { Db } from "./db";
import { getDb } from "./db";

/**
 * 88Risers coins are free-to-earn play money: never sold, no cash value.
 * Earned: welcome bonus, correct supermatch picks (+ doubled stakes), first game run each day,
 * organiser grants. Spent: supermatch stakes and the reward store below.
 */
export const WELCOME_COINS = 25;
export const DAILY_GAME_COINS = 5;
export const MAX_STAKE = 500;

export type ItemKind = "frame" | "title" | "handle" | "badge" | "perk" | "entry";
export interface StoreItem {
  id: string;
  kind: ItemKind;
  name: string;
  cost: number;
  blurb: string;
  /** Max purchases per account (cosmetics and perks are one-off). */
  limit: number;
  /** For frames: the CSS class applied to the account card. */
  style?: string;
}

export const STORE: StoreItem[] = [
  { id: "frame-gold", kind: "frame", name: "Gold frame", cost: 60, blurb: "A brushed gold border for your Riser card.", limit: 1, style: "gold" },
  { id: "frame-ink", kind: "frame", name: "Red ink frame", cost: 100, blurb: "Brushstroke red ring, straight off the crest.", limit: 1, style: "ink" },
  { id: "frame-holo", kind: "frame", name: "Holo frame", cost: 180, blurb: "Shimmering holographic foil, like the champion cards.", limit: 1, style: "holo" },
  {
    id: "title",
    kind: "title",
    name: "Custom title",
    cost: 80,
    blurb: "A tagline shown under your name on your pass, profile and search card, e.g. “Hook specialist”. Your name and @handle stay the same. Buy again to change it.",
    limit: 1,
  },
  {
    id: "handle",
    kind: "handle",
    name: "Change your @handle",
    cost: 20,
    blurb: "Swap your username for a new one. You log in with the new @handle, and your profile link changes with it. Coins, Chalk and picks all carry over.",
    limit: 1,
  },
  { id: "badge-lion", kind: "badge", name: "Lion badge", cost: 120, blurb: "The lion sits on your card and next to your name on leaderboards.", limit: 1 },
  { id: "perk-sticker", kind: "perk", name: "Sticker pack at a meet", cost: 150, blurb: "Show your code at table time and grab a sticker pack.", limit: 1 },
  { id: "perk-tee-10", kind: "perk", name: "10% off a Club Tee", cost: 500, blurb: "A discount code for when the shop opens.", limit: 1 },
  { id: "entry-tee", kind: "entry", name: "Giveaway entry: Club Tee", cost: 20, blurb: "One entry in the next Club Tee draw. Up to 10 entries.", limit: 10 },
];

export const itemById = (id: string) => STORE.find((i) => i.id === id) ?? null;
/** Items you can buy again and again (each purchase replaces the last). */
export const isRepeatable = (i: StoreItem) => i.kind === "title" || i.kind === "handle";

export async function balanceOf(db: Db, accountId: number) {
  const [r] = await db.query<{ n: number }>(`SELECT coalesce(sum(amount), 0)::int AS n FROM coin_tx WHERE account_id = $1`, [accountId]);
  return r.n;
}

/** Locks the account row so concurrent spends can't overdraw. Use inside a transaction. */
export async function lockAccount(tx: Db, accountId: number) {
  await tx.query(`SELECT id FROM accounts WHERE id = $1 FOR UPDATE`, [accountId]);
}

/** Adds coins once per ref; returns whether it was credited. */
export async function grant(db: Db, accountId: number, amount: number, reason: string, ref: string | null) {
  const r = await db.query(
    `INSERT INTO coin_tx (account_id, amount, reason, ref) VALUES ($1, $2, $3, $4)
     ON CONFLICT (account_id, ref) DO NOTHING RETURNING id`,
    [accountId, amount, reason, ref],
  );
  return r.length > 0;
}

export const newCode = () => `88R-${randomBytes(3).toString("hex").toUpperCase()}`;

export interface CoinRow {
  amount: number;
  reason: string;
  created_at: string;
}

export async function coinHistory(accountId: number) {
  const db = await getDb();
  return db.query<CoinRow>(`SELECT amount, reason, created_at FROM coin_tx WHERE account_id = $1 ORDER BY id DESC LIMIT 30`, [accountId]);
}

export interface Style {
  frame: string | null;
  title: string | null;
  badge: boolean;
}

export async function styleOf(accountId: number): Promise<Style> {
  const db = await getDb();
  const [s] = await db.query<Style>(`SELECT frame, title, badge FROM account_style WHERE account_id = $1`, [accountId]);
  return s ?? { frame: null, title: null, badge: false };
}

export interface Redemption {
  id: number;
  item: string;
  cost: number;
  code: string;
  fulfilled: boolean;
  won: boolean;
  created_at: string;
}

export async function redemptionsOf(accountId: number) {
  const db = await getDb();
  return db.query<Redemption>(
    `SELECT id, item, cost, code, fulfilled, won, created_at FROM redemptions WHERE account_id = $1 ORDER BY id DESC`,
    [accountId],
  );
}

export interface CoinLeader {
  display_name: string;
  handle: string;
  coins: number;
  badge: boolean;
}

export async function coinLeaders(limit = 10) {
  const db = await getDb();
  return db.query<CoinLeader>(
    `SELECT a.display_name, a.handle, coalesce(s.badge, false) AS badge,
            coalesce((SELECT sum(amount) FROM coin_tx t WHERE t.account_id = a.id), 0)::int AS coins
     FROM accounts a LEFT JOIN account_style s ON s.account_id = a.id
     ORDER BY coins DESC, a.id ASC LIMIT $1`,
    [limit],
  );
}

/* ─────────── Admin views ─────────── */

export interface AdminAccount {
  id: number;
  handle: string;
  display_name: string;
  created_at: string;
  coins: number;
  picks: number;
  best: number | null;
  /** Previous handles, e.g. "@daddy". */
  former: string | null;
}

export async function adminAccounts() {
  const db = await getDb();
  return db.query<AdminAccount>(
    `SELECT a.id, a.handle, a.display_name, a.created_at,
            coalesce((SELECT sum(amount) FROM coin_tx t WHERE t.account_id = a.id), 0)::int AS coins,
            (SELECT count(*)::int FROM predictions p WHERE p.account_id = a.id) AS picks,
            (SELECT best FROM game_scores g WHERE g.account_id = a.id) AS best,
            (SELECT string_agg('@' || h.old_handle, ', ' ORDER BY h.changed_at) FROM handle_history h WHERE h.account_id = a.id) AS former
     FROM accounts a ORDER BY a.created_at DESC`,
  );
}

export interface AdminRedemption extends Redemption {
  display_name: string;
  handle: string;
}

export async function adminRedemptions() {
  const db = await getDb();
  return db.query<AdminRedemption>(
    `SELECT r.id, r.item, r.cost, r.code, r.fulfilled, r.won, r.created_at, a.display_name, a.handle
     FROM redemptions r JOIN accounts a ON a.id = r.account_id
     WHERE r.item NOT LIKE 'frame-%' AND r.item NOT IN ('title', 'badge-lion')
     ORDER BY r.fulfilled ASC, r.id DESC LIMIT 300`,
  );
}
