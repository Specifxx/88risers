"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { cleanHandle, currentAccount, endSession, hashPassword, startSession, verifyPassword } from "@/lib/auth";
import { DAILY_GAME_COINS, MAX_STAKE, WELCOME_COINS, balanceOf, grant, itemById, lockAccount, newCode } from "@/lib/coins";
import { getDb } from "@/lib/db";
import { fmtOdds, payoutAt, quoteOdds } from "@/lib/odds";
import { SITE } from "@/lib/site";

export type FormState = { status: "idle" } | { status: "error"; message: string; field?: string } | { status: "ok"; message: string };

const s = (f: FormData, k: string) => String(f.get(k) ?? "").trim();
/** Only same-site relative paths, so the "next" param can't send people elsewhere. */
const safeNext = (n: string) => (/^\/(?!\/)[\w\-/?=&#.]*$/.test(n) ? n : "/account");

/* ─────────── Accounts ─────────── */

export async function signUp(_prev: FormState, form: FormData): Promise<FormState> {
  if (s(form, "company")) return { status: "idle" };
  const name = s(form, "display_name").replace(/\s+/g, " ");
  const handle = cleanHandle(s(form, "handle"));
  const password = String(form.get("password") ?? "");
  if (name.length < 2 || name.length > 40) return { status: "error", field: "display_name", message: "Your name needs 2–40 characters." };
  if (!handle) return { status: "error", field: "handle", message: "Usernames are 3–20 letters, numbers or underscores." };
  if (password.length < 8) return { status: "error", field: "password", message: "Use at least 8 characters." };
  if (password.length > 200) return { status: "error", field: "password", message: "That password is too long." };

  const db = await getDb();
  let id: number;
  try {
    const hash = await hashPassword(password);
    const rows = await db.query<{ id: number }>(
      `INSERT INTO accounts (handle, display_name, pass_hash) VALUES ($1, $2, $3) ON CONFLICT (handle) DO NOTHING RETURNING id`,
      [handle, name, hash],
    );
    if (!rows.length) return { status: "error", field: "handle", message: "That username is taken. Try another." };
    id = rows[0].id;
    await grant(db, id, WELCOME_COINS, "Welcome to the pride", "welcome");
    await startSession(id);
  } catch (err) {
    console.error("signUp failed", err);
    return { status: "error", message: "Something went wrong on our side. Try again." };
  }
  redirect(safeNext(s(form, "next")));
}

export async function logIn(_prev: FormState, form: FormData): Promise<FormState> {
  const handle = cleanHandle(s(form, "handle"));
  const password = String(form.get("password") ?? "");
  const wrong: FormState = { status: "error", message: "That username and password don't match." };
  if (!handle || !password) return wrong;

  const db = await getDb();
  try {
    // Slow down guessing: 10 failed tries per username per 15 minutes.
    const [{ n }] = await db.query<{ n: number }>(
      `SELECT count(*)::int AS n FROM login_attempts WHERE handle = $1 AND at > now() - interval '15 minutes'`,
      [handle],
    );
    if (n >= 10) return { status: "error", message: "Too many tries. Wait 15 minutes and try again." };
    const [acct] = await db.query<{ id: number; pass_hash: string }>(`SELECT id, pass_hash FROM accounts WHERE handle = $1`, [handle]);
    if (!acct || !(await verifyPassword(password, acct.pass_hash))) {
      await db.query(`INSERT INTO login_attempts (handle) VALUES ($1)`, [handle]);
      return wrong;
    }
    await db.query(`DELETE FROM login_attempts WHERE handle = $1 OR at < now() - interval '1 day'`, [handle]);
    await startSession(acct.id);
  } catch (err) {
    console.error("logIn failed", err);
    return { status: "error", message: "Something went wrong on our side. Try again." };
  }
  redirect(safeNext(s(form, "next")));
}

export async function logOut() {
  await endSession();
  redirect("/account");
}

/* ─────────── Supermatch picks ─────────── */

export async function castPick(_prev: FormState, form: FormData): Promise<FormState> {
  const me = await currentAccount();
  if (!me) return { status: "error", message: "Log in to make your pick." };
  const matchId = Number(s(form, "match_id"));
  const pick = Number(s(form, "pick_id"));
  const stake = Math.floor(Number(s(form, "stake") || 0));
  if (!Number.isFinite(stake) || stake < 0 || stake > MAX_STAKE)
    return { status: "error", message: `Stakes are 0–${MAX_STAKE} coins.` };

  const db = await getDb();
  let locked = 0;
  try {
    const res = await db.transaction(async (tx) => {
      // Row lock: bets on one match are priced one at a time, so each sees the previous ones.
      const [m] = await tx.query<{ a_id: number; b_id: number; closes_at: string; settled_at: string | null }>(
        `SELECT a_id, b_id, closes_at, settled_at FROM supermatches WHERE id = $1 FOR UPDATE`,
        [matchId],
      );
      if (!m) return "That match doesn't exist.";
      if (m.settled_at || new Date(m.closes_at).getTime() <= Date.now()) return "Voting has closed for this match.";
      if (pick !== m.a_id && pick !== m.b_id) return "Pick one of the two pullers.";
      await lockAccount(tx, me.id);
      const [already] = await tx.query(`SELECT 1 FROM predictions WHERE match_id = $1 AND account_id = $2`, [matchId, me.id]);
      if (already) return "You've already locked in your pick.";
      if (stake > 0 && (await balanceOf(tx, me.id)) < stake) return "You don't have that many coins.";
      const [pools] = await tx.query<{ a: number; b: number }>(
        `SELECT coalesce(sum(stake) FILTER (WHERE pick_id = $2), 0)::int AS a,
                coalesce(sum(stake) FILTER (WHERE pick_id = $3), 0)::int AS b
         FROM predictions WHERE match_id = $1`,
        [matchId, m.a_id, m.b_id],
      );
      locked = quoteOdds(pick === m.a_id ? "a" : "b", pools);
      await tx.query(`INSERT INTO predictions (match_id, account_id, pick_id, stake, odds) VALUES ($1, $2, $3, $4, $5)`, [
        matchId, me.id, pick, stake, locked,
      ]);
      if (stake > 0) await grant(tx, me.id, -stake, "Supermatch stake", `sm:${matchId}:stake`);
      return null;
    });
    if (res) return { status: "error", message: res };
  } catch (err) {
    console.error("castPick failed", err);
    return { status: "error", message: "Something went wrong on our side. Try again." };
  }
  return {
    status: "ok",
    message: stake
      ? `Locked in: ${stake} coins at ${fmtOdds(locked)}. Pays ${payoutAt(stake, locked)} if you're right.`
      : "Pick locked in.",
  };
}

/* ─────────── Reward store ─────────── */

export async function buyItem(_prev: FormState, form: FormData): Promise<FormState> {
  const me = await currentAccount();
  if (!me) return { status: "error", message: "Log in to use your coins." };
  const item = itemById(s(form, "item"));
  if (!item) return { status: "error", message: "That item isn't available." };
  const title = s(form, "title").replace(/\s+/g, " ").slice(0, 32);
  if (item.kind === "title" && title.length < 2) return { status: "error", message: "Type the title you want (2–32 characters)." };

  const db = await getDb();
  let code = "";
  try {
    const res = await db.transaction(async (tx) => {
      await lockAccount(tx, me.id);
      const [{ n }] = await tx.query<{ n: number }>(
        `SELECT count(*)::int AS n FROM redemptions WHERE account_id = $1 AND item = $2`,
        [me.id, item.id],
      );
      // A title can be changed later by buying again; everything else respects its limit.
      if (item.kind !== "title" && n >= item.limit)
        return item.limit === 1 ? "You already own this." : `That's the limit of ${item.limit}.`;
      if ((await balanceOf(tx, me.id)) < item.cost) return "Not enough coins yet.";
      code = newCode();
      await tx.query(`INSERT INTO redemptions (account_id, item, cost, code) VALUES ($1, $2, $3, $4)`, [me.id, item.id, item.cost, code]);
      await tx.query(`INSERT INTO coin_tx (account_id, amount, reason) VALUES ($1, $2, $3)`, [me.id, -item.cost, item.name]);
      await tx.query(`INSERT INTO account_style (account_id) VALUES ($1) ON CONFLICT DO NOTHING`, [me.id]);
      if (item.kind === "frame") await tx.query(`UPDATE account_style SET frame = $2 WHERE account_id = $1`, [me.id, item.style]);
      if (item.kind === "title") await tx.query(`UPDATE account_style SET title = $2 WHERE account_id = $1`, [me.id, title]);
      if (item.kind === "badge") await tx.query(`UPDATE account_style SET badge = true WHERE account_id = $1`, [me.id]);
      return null;
    });
    if (res) return { status: "error", message: res };
  } catch (err) {
    console.error("buyItem failed", err);
    return { status: "error", message: "Something went wrong on our side. Try again." };
  }
  const msg =
    item.kind === "perk"
      ? `Done! Your code is ${code}. Show it to an organiser.`
      : item.kind === "entry"
        ? `You're in the draw (code ${code}). Good luck!`
        : `${item.name} unlocked and equipped.`;
  return { status: "ok", message: msg };
}

/** Switch between frames you already own (or none). */
export async function equipFrame(form: FormData) {
  const me = await currentAccount();
  if (!me) return;
  const style = s(form, "frame") || null;
  const db = await getDb();
  if (style) {
    const item = STORE_FRAME_BY_STYLE[style];
    const [own] = item ? await db.query(`SELECT 1 FROM redemptions WHERE account_id = $1 AND item = $2`, [me.id, item]) : [];
    if (!own) return;
  }
  await db.query(`INSERT INTO account_style (account_id) VALUES ($1) ON CONFLICT DO NOTHING`, [me.id]);
  await db.query(`UPDATE account_style SET frame = $2 WHERE account_id = $1`, [me.id, style]);
  revalidatePath("/account");
}
const STORE_FRAME_BY_STYLE: Record<string, string> = { gold: "frame-gold", ink: "frame-ink", holo: "frame-holo" };

/* ─────────── Game ─────────── */

export async function submitScore(score: number): Promise<{ best: number | null; coins: number; message: string }> {
  const me = await currentAccount();
  if (!me) return { best: null, coins: 0, message: "Log in to save your score and earn coins." };
  const n = Math.floor(Number(score));
  if (!Number.isFinite(n) || n < 0 || n > 2_000_000) return { best: null, coins: 0, message: "Score not saved." };
  const db = await getDb();
  const [row] = await db.query<{ best: number }>(
    `INSERT INTO game_scores (account_id, best) VALUES ($1, $2)
     ON CONFLICT (account_id) DO UPDATE SET best = GREATEST(game_scores.best, EXCLUDED.best),
       updated_at = CASE WHEN EXCLUDED.best > game_scores.best THEN now() ELSE game_scores.updated_at END
     RETURNING best`,
    [me.id, n],
  );
  const day = new Intl.DateTimeFormat("en-CA", { timeZone: SITE.timeZone }).format(new Date());
  const got = n >= 100 && (await grant(db, me.id, DAILY_GAME_COINS, "Pin Run: daily run", `game:${day}`));
  revalidatePath("/play");
  return {
    best: row.best,
    coins: got ? DAILY_GAME_COINS : 0,
    message: got ? `+${DAILY_GAME_COINS} coins for today's run!` : n > 0 && row.best === n ? "New personal best!" : "Score saved.",
  };
}
