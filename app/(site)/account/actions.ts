"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { changePassword, cleanHandle, consumeReset, currentAccount, endSession, hashPassword, startSession, verifyPassword } from "@/lib/auth";
import { DAILY_GAME_COINS, MAX_STAKE, WELCOME_COINS, balanceOf, grant, isRepeatable, itemById, lockAccount, newCode } from "@/lib/coins";
import { RTP_GAME, RTP_LEVELS, RTP_MAX_SCORE, isRtpLevel } from "@/lib/arcade";
import { CHALK, recordCheckin, sydneyToday } from "@/lib/chalk";
import { type Db, getDb } from "@/lib/db";
import { LEVEL2_UNLOCK, type Wallet, skinById } from "@/lib/pinrun";
import { bankRunCoins, getWallet } from "@/lib/pinrun-db";
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
  const invitedRaw = s(form, "invited_by").replace(/^@/, "");
  const invitedHandle = invitedRaw ? cleanHandle(invitedRaw) : null;
  if (invitedRaw && !invitedHandle) return { status: "error", field: "invited_by", message: "That doesn't look like a username." };

  const db = await getDb();
  let invitedBy: number | null = null;
  if (invitedHandle) {
    const [inv] = await db.query<{ id: number }>(
      `SELECT id FROM accounts WHERE handle = $1 UNION ALL SELECT account_id FROM handle_history WHERE old_handle = $1 LIMIT 1`,
      [invitedHandle],
    );
    if (!inv) return { status: "error", field: "invited_by", message: "We couldn't find that member. Check the username, or leave it blank." };
    invitedBy = inv.id;
  }
  let id: number;
  try {
    const hash = await hashPassword(password);
    const rows = await db.query<{ id: number }>(
      `INSERT INTO accounts (handle, display_name, pass_hash, invited_by) VALUES ($1, $2, $3, $4) ON CONFLICT (handle) DO NOTHING RETURNING id`,
      [handle, name, hash, invitedBy],
    );
    if (!rows.length) return { status: "error", field: "handle", message: "That username is taken. Try another." };
    id = rows[0].id;
    await db.query(`DELETE FROM handle_history WHERE old_handle = $1`, [handle]);
    await grant(db, id, WELCOME_COINS, "Welcome bonus", "welcome");
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

/** Sets a new password from a reset link an organiser sent, then logs the member in. */
export async function resetPassword(_prev: FormState, form: FormData): Promise<FormState> {
  const token = s(form, "token");
  const pw = String(form.get("password") ?? "");
  if (pw.length < 8) return { status: "error", field: "password", message: "Use at least 8 characters." };
  if (pw !== String(form.get("confirm") ?? "")) return { status: "error", field: "confirm", message: "Those passwords don't match." };
  let id: number | null = null;
  try {
    id = await consumeReset(token, pw);
  } catch (err) {
    console.error("resetPassword failed", err);
    return { status: "error", message: "Something went wrong on our side. Try again." };
  }
  if (!id) return { status: "error", message: "This reset link has expired or was already used. Ask an organiser for a new one." };
  await startSession(id);
  redirect("/account?reset=1");
}

export async function updatePassword(_prev: FormState, form: FormData): Promise<FormState> {
  const me = await currentAccount();
  if (!me) return { status: "error", message: "Log in first." };
  const next = String(form.get("password") ?? "");
  if (next.length < 8) return { status: "error", field: "password", message: "Use at least 8 characters." };
  if (next !== String(form.get("confirm") ?? "")) return { status: "error", field: "confirm", message: "Those passwords don't match." };
  const ok = await changePassword(me.id, String(form.get("current") ?? ""), next);
  if (!ok) return { status: "error", field: "current", message: "Your current password isn't right." };
  return { status: "ok", message: "Password changed. Other devices have been logged out." };
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
  const newHandle = item.kind === "handle" ? cleanHandle(s(form, "handle")) : null;
  if (item.kind === "handle") {
    if (!newHandle) return { status: "error", message: "Handles are 3–20 letters, numbers or underscores." };
    if (newHandle === me.handle) return { status: "error", message: "That's already your handle." };
  }

  const db = await getDb();
  let code = "";
  try {
    const res = await db.transaction(async (tx) => {
      await lockAccount(tx, me.id);
      const [{ n }] = await tx.query<{ n: number }>(
        `SELECT count(*)::int AS n FROM redemptions WHERE account_id = $1 AND item = $2`,
        [me.id, item.id],
      );
      // Titles and handles can be changed again by buying again; everything else respects its limit.
      if (!isRepeatable(item) && n >= item.limit)
        return item.limit === 1 ? "You already own this." : `That's the limit of ${item.limit}.`;
      if ((await balanceOf(tx, me.id)) < item.cost) return "Not enough coins yet.";
      if (newHandle) {
        const [taken] = await tx.query(`SELECT 1 FROM accounts WHERE handle = $1`, [newHandle]);
        if (taken) return `@${newHandle} is taken. Try another.`;
        await tx.query(`UPDATE accounts SET handle = $2 WHERE id = $1`, [me.id, newHandle]);
        // Old profile links redirect to the new handle; a handle that's in use again stops redirecting.
        await tx.query(`DELETE FROM handle_history WHERE old_handle = $1`, [newHandle]);
        await tx.query(
          `INSERT INTO handle_history (old_handle, account_id) VALUES ($1, $2)
           ON CONFLICT (old_handle) DO UPDATE SET account_id = EXCLUDED.account_id, changed_at = now()`,
          [me.handle, me.id],
        );
      }
      code = newCode();
      await tx.query(`INSERT INTO redemptions (account_id, item, cost, code) VALUES ($1, $2, $3, $4)`, [me.id, item.id, item.cost, code]);
      await tx.query(`INSERT INTO coin_tx (account_id, amount, reason) VALUES ($1, $2, $3)`, [
        me.id,
        -item.cost,
        newHandle ? `Changed handle @${me.handle} → @${newHandle}` : item.name,
      ]);
      await tx.query(`INSERT INTO account_style (account_id) VALUES ($1) ON CONFLICT DO NOTHING`, [me.id]);
      if (item.kind === "frame") await tx.query(`UPDATE account_style SET frame = $2 WHERE account_id = $1`, [me.id, item.style]);
      if (item.kind === "title") await tx.query(`UPDATE account_style SET title = $2 WHERE account_id = $1`, [me.id, title]);
      if (item.kind === "badge") await tx.query(`UPDATE account_style SET badge = true WHERE account_id = $1`, [me.id]);
      return null;
    });
    if (res) return { status: "error", message: res };
  } catch (err) {
    if (newHandle && /unique|duplicate/i.test(String(err))) return { status: "error", message: `@${newHandle} is taken. Try another.` };
    console.error("buyItem failed", err);
    return { status: "error", message: "Something went wrong on our side. Try again." };
  }
  // Handles appear on cached public pages (leaderboards, Riser profiles): refresh them now.
  if (newHandle) revalidatePath("/", "layout");
  const msg =
    item.kind === "perk"
      ? `Done! Your code is ${code}. Show it to an organiser.`
      : item.kind === "entry"
        ? `You're in the draw (code ${code}). Good luck!`
        : item.kind === "handle"
          ? `Done! You're now @${newHandle}. Use it next time you log in.`
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

/** +5 coins for the first minigame played each day (Sydney time), whichever game it is. */
async function dailyGameBonus(db: Db, accountId: number, game: string) {
  const day = new Intl.DateTimeFormat("en-CA", { timeZone: SITE.timeZone }).format(new Date());
  return grant(db, accountId, DAILY_GAME_COINS, `Daily game bonus (${game})`, `game:${day}`);
}

/** Race to the Pin calls this when any match finishes, win or lose. */
export async function claimDailyGameCoins(): Promise<{ coins: number }> {
  const me = await currentAccount();
  if (!me) return { coins: 0 };
  const db = await getDb();
  const got = await dailyGameBonus(db, me.id, "Race to the Pin");
  if (got) revalidatePath("/account");
  return { coins: got ? DAILY_GAME_COINS : 0 };
}

export async function submitScore(
  score: number,
  runCoins = 0,
  level = 1,
): Promise<{ best: number | null; coins: number; message: string; saved: number; wallet: Wallet | null; l1Best?: number }> {
  const me = await currentAccount();
  if (!me) return { best: null, coins: 0, message: "Log in to save your score and earn coins.", saved: 0, wallet: null };
  const n = Math.floor(Number(score));
  if (!Number.isFinite(n) || n < 0 || n > 2_000_000) return { best: null, coins: 0, message: "Score not saved.", saved: 0, wallet: null };
  const db = await getDb();
  if (level === 2) {
    // Level 2 has its own leaderboard, and only counts once Level 1 has unlocked it.
    const [l1] = await db.query<{ best: number; l2: boolean }>(
      `SELECT (SELECT best FROM game_scores WHERE account_id = $1) AS best,
              coalesce((SELECT l2 FROM pinrun_wallet WHERE account_id = $1), false) AS l2`,
      [me.id],
    );
    if ((l1?.best ?? 0) < LEVEL2_UNLOCK && !l1?.l2) return { best: null, coins: 0, message: "Level 2 isn't unlocked yet.", saved: 0, wallet: null };
    const [row2] = await db.query<{ best: number }>(
      `INSERT INTO arcade_scores (account_id, game, level, best) VALUES ($1, 'pinrun', '2', $2)
       ON CONFLICT (account_id, game, level) DO UPDATE SET best = GREATEST(arcade_scores.best, EXCLUDED.best),
         updated_at = CASE WHEN EXCLUDED.best > arcade_scores.best THEN now() ELSE arcade_scores.updated_at END
       RETURNING best`,
      [me.id, n],
    );
    const got2 = await dailyGameBonus(db, me.id, "Pin Run");
    const bank2 = await bankRunCoins(me.id, n, runCoins);
    revalidatePath("/play");
    return {
      saved: bank2.saved,
      wallet: bank2.wallet,
      best: row2.best,
      coins: got2 ? DAILY_GAME_COINS : 0,
      message: got2
        ? `+${DAILY_GAME_COINS} 88Risers coins for today's game!`
        : `${n > 0 && row2.best === n ? "New Level 2 best!" : "Score saved."} Today's +${DAILY_GAME_COINS} 88Risers coins already collected.`,
    };
  }
  const [row] = await db.query<{ best: number }>(
    `INSERT INTO game_scores (account_id, best) VALUES ($1, $2)
     ON CONFLICT (account_id) DO UPDATE SET best = GREATEST(game_scores.best, EXCLUDED.best),
       updated_at = CASE WHEN EXCLUDED.best > game_scores.best THEN now() ELSE game_scores.updated_at END
     RETURNING best`,
    [me.id, n],
  );
  const got = await dailyGameBonus(db, me.id, "Pin Run");
  const bank = await bankRunCoins(me.id, n, runCoins);
  revalidatePath("/play");
  return {
    saved: bank.saved,
    wallet: bank.wallet,
    best: row.best,
    l1Best: row.best,
    coins: got ? DAILY_GAME_COINS : 0,
    message: got
      ? `+${DAILY_GAME_COINS} 88Risers coins for today's game!`
      : `${n > 0 && row.best === n ? "New personal best!" : "Score saved."} Today's +${DAILY_GAME_COINS} 88Risers coins already collected.`,
  };
}

/** Race to the Pin: keep each Riser's best winning score per difficulty. */
export async function submitArcadeScore(level: string, score: number): Promise<{ saved: boolean; best: number | null; message: string }> {
  const me = await currentAccount();
  if (!me) return { saved: false, best: null, message: "Log in to put your wins on the leaderboard." };
  const n = Math.floor(Number(score));
  if (!isRtpLevel(level) || !Number.isFinite(n) || n <= 0 || n > RTP_MAX_SCORE) return { saved: false, best: null, message: "Score not saved." };
  const db = await getDb();
  const [prev] = await db.query<{ best: number }>(
    `SELECT best FROM arcade_scores WHERE account_id = $1 AND game = $2 AND level = $3`,
    [me.id, RTP_GAME, level],
  );
  const [row] = await db.query<{ best: number }>(
    `INSERT INTO arcade_scores (account_id, game, level, best) VALUES ($1, $2, $3, $4)
     ON CONFLICT (account_id, game, level) DO UPDATE SET best = GREATEST(arcade_scores.best, EXCLUDED.best),
       updated_at = CASE WHEN EXCLUDED.best > arcade_scores.best THEN now() ELSE arcade_scores.updated_at END
     RETURNING best`,
    [me.id, RTP_GAME, level, n],
  );
  const name = RTP_LEVELS.find((l) => l.id === level)!.name;
  const isBest = !prev || n > prev.best;
  return {
    saved: true,
    best: row.best,
    message: isBest ? `New ${name} best: ${n.toLocaleString("en-AU")}! Saved to the leaderboard.` : `Win saved. Your ${name} best is ${row.best.toLocaleString("en-AU")}.`,
  };
}

/* ─────────── Chalk check-in ─────────── */

/** Meet-day check-in with the code the organisers show at the table. */
export async function checkIn(_prev: FormState, form: FormData): Promise<FormState> {
  const me = await currentAccount();
  if (!me) return { status: "error", message: "Log in to check in." };
  const code = s(form, "code").replace(/\D/g, "");
  const db = await getDb();
  // Wrong codes are limited so nobody can guess their way in.
  const guessKey = `checkin:${me.handle}`;
  const [{ n }] = await db.query<{ n: number }>(
    `SELECT count(*)::int AS n FROM login_attempts WHERE handle = $1 AND at > now() - interval '1 day'`,
    [guessKey],
  );
  if (n >= 8) return { status: "error", message: "Too many wrong codes today. Ask an organiser to check you in." };
  try {
    const res = await db.transaction(async (tx) => {
      const [meet] = await tx.query<{ id: number; day: string; code: string; open: boolean }>(
        `SELECT id, day::text AS day, code, open FROM meets WHERE day = $1::date`,
        [sydneyToday()],
      );
      if (!meet || !meet.open) return "Check-in isn't open right now. It opens at the meet.";
      if (code !== meet.code) {
        await tx.query(`INSERT INTO login_attempts (handle) VALUES ($1)`, [guessKey]);
        return "That code isn't right. Check the code at the table.";
      }
      return (await recordCheckin(tx, meet, me.id)) ? null : "You're already checked in. See you at the table!";
    });
    if (res) return { status: "error", message: res };
  } catch (err) {
    console.error("checkIn failed", err);
    return { status: "error", message: "Something went wrong on our side. Try again." };
  }
  return { status: "ok", message: `Checked in! +${CHALK.checkin} Chalk.` };
}

/* ─────────── Pin Run: Lion Temple ─────────── */

export async function buySkin(id: string): Promise<{ ok: boolean; message: string; wallet: Wallet | null }> {
  const me = await currentAccount();
  if (!me) return { ok: false, message: "Log in to unlock lions.", wallet: null };
  const skin = skinById(id);
  if (!skin) return { ok: false, message: "That lion isn't in the temple.", wallet: null };
  const db = await getDb();
  const res = await db.transaction(async (tx) => {
    await tx.query(`INSERT INTO pinrun_wallet (account_id) VALUES ($1) ON CONFLICT DO NOTHING`, [me.id]);
    const [w] = await tx.query<Wallet>(`SELECT coins, skin, owned FROM pinrun_wallet WHERE account_id = $1 FOR UPDATE`, [me.id]);
    if (w.owned.includes(skin.id)) return "You already have this lion.";
    if (w.coins < skin.price) return `You need ${skin.price - w.coins} more Temple coins.`;
    await tx.query(
      `UPDATE pinrun_wallet SET coins = coins - $2, owned = array_append(owned, $3), skin = $3, updated_at = now() WHERE account_id = $1`,
      [me.id, skin.price, skin.id],
    );
    await tx.query(`INSERT INTO pinrun_tx (account_id, amount, reason) VALUES ($1, $2, $3)`, [me.id, -skin.price, `Lion skin: ${skin.name}`]);
    return null;
  });
  const wallet = await getWallet(me.id);
  if (res) return { ok: false, message: res, wallet };
  return { ok: true, message: `${skin.name} unlocked and equipped.`, wallet };
}

export async function equipSkin(id: string): Promise<{ ok: boolean; wallet: Wallet | null }> {
  const me = await currentAccount();
  if (!me || !skinById(id)) return { ok: false, wallet: null };
  const db = await getDb();
  await db.query(`UPDATE pinrun_wallet SET skin = $2, updated_at = now() WHERE account_id = $1 AND $2 = ANY(owned)`, [me.id, id]);
  return { ok: true, wallet: await getWallet(me.id) };
}
