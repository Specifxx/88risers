"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { assertAdmin } from "@/lib/admin";
import { NEXT_ID_SQL, PICK_MAX, PICK_MIN, recomputeElo } from "@/lib/data";
import { getDb, type Db } from "@/lib/db";
import { savePhoto, photoUrl } from "@/lib/photos";
import { fromSydneyInput } from "@/lib/schedule";
import { setGiveawayDrawAt } from "@/lib/giveaway";
import { awardResultsChalk } from "@/lib/results";
import { CHALK, awardChalk, currentSeason, meetLabel, newMeetCode, recordCheckin, saveChalkSettings, sydneyToday } from "@/lib/chalk";
import { liveEmbed, videoEmbed } from "@/lib/video";
import { saveLiveSettings } from "@/lib/tv";
import { mailConfigured, mailStatus, sendClubMail } from "@/lib/mail";
import { createResetToken, hashPassword } from "@/lib/auth";
import { grant, itemById } from "@/lib/coins";
import { fmtOdds, oddsOf, payoutAt } from "@/lib/odds";

type Tab = "registrations" | "pullers" | "matches" | "events" | "tv" | "shop" | "coins" | "chalk";

const str = (f: FormData, k: string) => {
  const v = f.get(k);
  return typeof v === "string" && v.trim() ? v.trim() : null;
};
const int = (f: FormData, k: string) => {
  const v = str(f, k);
  return v && /^\d+$/.test(v) ? Number(v) : null;
};
const bool = (f: FormData, k: string) => f.get(k) === "on";

/** Every admin action re-checks the key from the URL it was submitted from. */
function guard(f: FormData) {
  const key = String(f.get("key") ?? "");
  assertAdmin(key);
  return key;
}

function done(key: string, tab: Tab, msg: string, isError = false): never {
  revalidatePath("/", "layout");
  redirect(`/admin/${encodeURIComponent(key)}?tab=${tab}&${isError ? "err" : "msg"}=${encodeURIComponent(msg)}`);
}

function friendly(err: unknown) {
  const m = err instanceof Error ? err.message : String(err);
  if (/pullers_pkey|duplicate key.*pullers/.test(m)) return "That Riser ID is already taken.";
  if (/events_slug_key/.test(m)) return "An event with that URL already exists — change the title or date.";
  if (/winner_id <> loser_id|matches_check/.test(m)) return "Winner and loser must be different pullers.";
  console.error(err);
  return "Something went wrong: " + m.slice(0, 140);
}

async function nextRiserId(db: Db) {
  const [r] = await db.query<{ n: number }>(`SELECT ${NEXT_ID_SQL} AS n`);
  return r.n;
}

async function publishPhoto(db: Db, form: FormData, field: string) {
  const res = await savePhoto(db, form.get(field), true);
  if (res && "error" in res) throw new Error(res.error);
  return res ? photoUrl(res.id) : null;
}

/* ─────────── Registrations ─────────── */

export async function promoteRegistration(form: FormData) {
  const key = guard(form);
  const regId = int(form, "registration_id");
  let message = "";
  try {
    const db = await getDb();
    message = await db.transaction(async (tx) => {
      const [reg] = await tx.query<{ name: string; instagram: string | null; photo_id: string | null; puller_id: number | null }>(
        `SELECT name, instagram, photo_id::text AS photo_id, puller_id FROM registrations WHERE id = $1`,
        [regId],
      );
      if (!reg) throw new Error("Registration not found");
      if (reg.puller_id) return `Already in the database as #${reg.puller_id}.`;
      const id = int(form, "riser_id") ?? (await nextRiserId(tx));
      if (reg.photo_id) await tx.query(`UPDATE photos SET is_public = true WHERE id = $1`, [reg.photo_id]);
      await tx.query(
        `INSERT INTO pullers (id, name, instagram, photo_url, registration_id) VALUES ($1, $2, $3, $4, $5)`,
        [id, reg.name, reg.instagram, reg.photo_id ? photoUrl(reg.photo_id) : null, regId],
      );
      await tx.query(`UPDATE registrations SET status = 'puller', puller_id = $2, updated_at = now() WHERE id = $1`, [regId, id]);
      return `${reg.name} is now Riser #${String(id).padStart(3, "0")}.`;
    });
  } catch (err) {
    done(key, "registrations", friendly(err), true);
  }
  done(key, "registrations", message);
}

export async function setRegistrationStatus(form: FormData) {
  const key = guard(form);
  const status = str(form, "status");
  if (!status || !["new", "contacted", "archived"].includes(status)) done(key, "registrations", "Unknown status", true);
  const db = await getDb();
  await db.query(`UPDATE registrations SET status = $2, updated_at = now() WHERE id = $1 AND status <> 'puller'`, [
    int(form, "registration_id"),
    status,
  ]);
  done(key, "registrations", "Updated.");
}

export async function saveRegistrationNote(form: FormData) {
  const key = guard(form);
  const db = await getDb();
  await db.query(`UPDATE registrations SET notes = $2, updated_at = now() WHERE id = $1`, [
    int(form, "registration_id"),
    str(form, "notes"),
  ]);
  done(key, "registrations", "Note saved.");
}

export async function deleteRegistration(form: FormData) {
  const key = guard(form);
  const db = await getDb();
  await db.transaction(async (tx) => {
    const [reg] = await tx.query<{ photo_id: string | null; puller_id: number | null }>(
      `DELETE FROM registrations WHERE id = $1 RETURNING photo_id::text AS photo_id, puller_id`,
      [int(form, "registration_id")],
    );
    // Keep the photo if it became a public puller photo.
    if (reg?.photo_id && !reg.puller_id) await tx.query(`DELETE FROM photos WHERE id = $1`, [reg.photo_id]);
  });
  done(key, "registrations", "Registration deleted.");
}

/* ─────────── Pullers ─────────── */

export async function savePuller(form: FormData) {
  const key = guard(form);
  const original = int(form, "original_id");
  const name = str(form, "name");
  if (!name) done(key, "pullers", "Name is required.", true);
  let message = "";
  try {
    const db = await getDb();
    message = await db.transaction(async (tx) => {
      const id = int(form, "id") ?? original ?? (await nextRiserId(tx));
      const photo = await publishPhoto(tx, form, "photo");
      const card = await publishPhoto(tx, form, "card");
      const fields = [
        name,
        str(form, "nickname"),
        str(form, "title"),
        str(form, "bio"),
        str(form, "weight_class"),
        str(form, "dominant_arm"),
        str(form, "instagram")?.replace(/^@/, "") ?? null,
        bool(form, "hidden"),
        str(form, "joined_on"),
      ];
      if (original) {
        await tx.query(
          `UPDATE pullers SET id = $1, name = $2, nickname = $3, title = $4, bio = $5, weight_class = $6,
             dominant_arm = $7, instagram = $8, hidden = $9, joined_on = coalesce($10::date, joined_on),
             photo_url = CASE WHEN $11::text IS NOT NULL THEN $11 WHEN $13 THEN NULL ELSE photo_url END,
             card_url  = CASE WHEN $12::text IS NOT NULL THEN $12 WHEN $14 THEN NULL ELSE card_url END
           WHERE id = $15`,
          [id, ...fields, photo, card, bool(form, "remove_photo"), bool(form, "remove_card"), original],
        );
        if (id !== original) await tx.query(`UPDATE registrations SET puller_id = $1 WHERE puller_id = $2`, [id, original]);
        return `Saved #${String(id).padStart(3, "0")} ${name}.`;
      }
      await tx.query(
        `INSERT INTO pullers (id, name, nickname, title, bio, weight_class, dominant_arm, instagram, hidden, joined_on, photo_url, card_url)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, coalesce($10::date, CURRENT_DATE), $11, $12)`,
        [id, ...fields, photo, card],
      );
      return `Added ${name} as Riser #${String(id).padStart(3, "0")}.`;
    });
  } catch (err) {
    done(key, "pullers", friendly(err), true);
  }
  done(key, "pullers", message);
}

export async function deletePuller(form: FormData) {
  const key = guard(form);
  const id = int(form, "id");
  const db = await getDb();
  await db.transaction(async (tx) => {
    await tx.query(`UPDATE registrations SET puller_id = NULL, status = 'contacted' WHERE puller_id = $1`, [id]);
    await tx.query(`DELETE FROM pullers WHERE id = $1`, [id]); // their matches cascade
    await recomputeElo(tx);
  });
  done(key, "pullers", `Deleted Riser #${id} and their matches.`);
}

/* ─────────── Matches ─────────── */

export async function saveMatch(form: FormData) {
  const key = guard(form);
  const id = int(form, "match_id");
  const winner = int(form, "winner_id");
  const loser = int(form, "loser_id");
  if (!winner || !loser) done(key, "matches", "Pick both a winner and a loser.", true);
  if (winner === loser) done(key, "matches", "Winner and loser must be different pullers.", true);
  const eventId = int(form, "event_id");
  const arm = str(form, "arm") === "left" ? "left" : "right";
  const video = str(form, "video_url");
  if (video && !/^https?:\/\//i.test(video)) done(key, "matches", "Video link must start with http(s)://", true);
  try {
    const db = await getDb();
    await db.transaction(async (tx) => {
      let playedOn = str(form, "played_on");
      if (!playedOn && eventId) {
        const [e] = await tx.query<{ d: string }>(
          `SELECT (starts_at AT TIME ZONE 'Australia/Sydney')::date::text AS d FROM events WHERE id = $1`,
          [eventId],
        );
        playedOn = e?.d ?? null;
      }
      const vals = [
        eventId,
        playedOn,
        arm,
        str(form, "round"),
        str(form, "weight_class"),
        str(form, "score"),
        winner,
        loser,
        video,
        bool(form, "is_title_match"),
        str(form, "notes"),
      ];
      if (id) {
        await tx.query(
          `UPDATE matches SET event_id=$1, played_on=coalesce($2::date, played_on), arm=$3, round=$4, weight_class=$5,
             score=$6, winner_id=$7, loser_id=$8, video_url=$9, is_title_match=$10, notes=$11 WHERE id=$12`,
          [...vals, id],
        );
      } else {
        await tx.query(
          `INSERT INTO matches (event_id, played_on, arm, round, weight_class, score, winner_id, loser_id, video_url, is_title_match, notes)
           VALUES ($1, coalesce($2::date, CURRENT_DATE), $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
          vals,
        );
      }
      await recomputeElo(tx);
    });
  } catch (err) {
    done(key, "matches", friendly(err), true);
  }
  done(key, "matches", id ? "Match updated." : "Match recorded.");
}

export async function deleteMatch(form: FormData) {
  const key = guard(form);
  const db = await getDb();
  await db.transaction(async (tx) => {
    await tx.query(`DELETE FROM matches WHERE id = $1`, [int(form, "match_id")]);
    await recomputeElo(tx);
  });
  done(key, "matches", "Match deleted.");
}

/* ─────────── Events ─────────── */

const slugify = (s: string) =>
  s
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[^\w\s-]/g, "")
    .trim()
    .replace(/[\s_-]+/g, "-")
    .slice(0, 60);

export async function saveEvent(form: FormData) {
  const key = guard(form);
  const id = int(form, "event_id");
  const title = str(form, "title");
  const starts = fromSydneyInput(str(form, "starts_at") ?? "");
  const endsRaw = str(form, "ends_at");
  const ends = endsRaw ? fromSydneyInput(endsRaw) : null;
  if (!title) done(key, "events", "Event title is required.", true);
  if (!starts) done(key, "events", "Pick a start date and time.", true);
  const kind = ["tournament", "training", "social", "other"].includes(str(form, "kind") ?? "") ? str(form, "kind") : "tournament";
  const slug = str(form, "slug") ? slugify(str(form, "slug")!) : `${slugify(title)}-${starts.toISOString().slice(0, 10)}`;
  try {
    const db = await getDb();
    const vals = [slug, title, kind, starts, ends, str(form, "venue"), str(form, "address"), str(form, "description"), bool(form, "cancelled")];
    if (id) {
      await db.query(
        `UPDATE events SET slug=$1, title=$2, kind=$3, starts_at=$4, ends_at=$5, venue=$6, address=$7, description=$8, cancelled=$9 WHERE id=$10`,
        [...vals, id],
      );
    } else {
      await db.query(
        `INSERT INTO events (slug, title, kind, starts_at, ends_at, venue, address, description, cancelled)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
        vals,
      );
    }
  } catch (err) {
    done(key, "events", friendly(err), true);
  }
  done(key, "events", id ? "Event updated." : `Event published at /events/${slug}`);
}

export async function deleteEvent(form: FormData) {
  const key = guard(form);
  const db = await getDb();
  await db.query(`DELETE FROM events WHERE id = $1`, [int(form, "event_id")]);
  done(key, "events", "Event deleted. Its matches were kept.");
}

/* ─────────── 88RisersTV ─────────── */

export async function saveReel(form: FormData) {
  const key = guard(form);
  const id = int(form, "reel_id");
  const url = str(form, "url");
  const title = str(form, "title");
  if (!url || !videoEmbed(url)) done(key, "tv", "Paste an Instagram reel link (or YouTube Short / TikTok).", true);
  if (!title) done(key, "tv", "Give the reel a title.", true);
  const posted = str(form, "posted_on");
  const vals = [url, title, str(form, "caption"), posted && /^\d{4}-\d{2}-\d{2}$/.test(posted) ? posted : null, int(form, "sort_order") ?? 0, bool(form, "hidden")];
  try {
    const db = await getDb();
    if (id) {
      await db.query(`UPDATE tv_reels SET url=$1, title=$2, caption=$3, posted_on=$4, sort_order=$5, hidden=$6 WHERE id=$7`, [...vals, id]);
    } else {
      await db.query(`INSERT INTO tv_reels (url, title, caption, posted_on, sort_order, hidden) VALUES ($1, $2, $3, $4, $5, $6)`, vals);
    }
  } catch (err) {
    done(key, "tv", friendly(err), true);
  }
  done(key, "tv", id ? "Reel updated." : "Reel added to 88RisersTV.");
}

export async function saveLiveFeed(form: FormData) {
  const key = guard(form);
  const url = str(form, "url");
  if (url && !liveEmbed(url)) done(key, "tv", "That stream link isn't supported. Use YouTube Live, Twitch, Kick or an .m3u8 link.", true);
  const m = str(form, "mode");
  await saveLiveSettings({ url, title: str(form, "title"), mode: m === "on" || m === "off" ? m : "auto" });
  done(key, "tv", url ? "Live feed saved." : "Live feed cleared. 88RisersTV plays the radio.");
}

export async function deleteReel(form: FormData) {
  const key = guard(form);
  const db = await getDb();
  await db.query(`DELETE FROM tv_reels WHERE id = $1`, [int(form, "reel_id")]);
  done(key, "tv", "Reel removed.");
}

/* ─────────── Shop interest ─────────── */

export async function setInterestDone(form: FormData) {
  const key = guard(form);
  const db = await getDb();
  await db.query(`UPDATE shop_interest SET done = $2 WHERE id = $1`, [int(form, "interest_id"), bool(form, "done")]);
  done(key, "shop", "Updated.");
}

export async function deleteInterest(form: FormData) {
  const key = guard(form);
  const db = await getDb();
  await db.query(`DELETE FROM shop_interest WHERE id = $1`, [int(form, "interest_id")]);
  done(key, "shop", "Removed.");
}

/** Sends a test email and reports Gmail's own error if it fails. */
export async function sendTestEmail(form: FormData) {
  const key = guard(form);
  if (!mailConfigured()) {
    const st = mailStatus();
    done(key, "shop", !st.user ? "GMAIL_USER isn't set on the live site yet." : "GMAIL_APP_PASSWORD isn't set on the live site yet.", true);
  }
  let error: string | null = null;
  try {
    await sendClubMail({
      subject: "88 Risers website: test email",
      text: "This is a test from the admin Shop tab. Shop interest notifications will arrive like this.",
    });
  } catch (err) {
    const m = err instanceof Error ? err.message : String(err);
    error = /535|Username and Password not accepted|Invalid login|BadCredentials/i.test(m)
      ? "Gmail rejected the login. Check GMAIL_USER is the full address and GMAIL_APP_PASSWORD is the 16-letter app password (not your normal password), then redeploy. Gmail said: " + m.slice(0, 160)
      : "Sending failed: " + m.slice(0, 200);
  }
  if (error) done(key, "shop", error, true);
  done(key, "shop", `Test email sent to ${mailStatus().to}. Check that inbox (and spam).`);
}

/* ─────────── Coins, supermatches, rewards ─────────── */

export async function saveSupermatch(form: FormData) {
  const key = guard(form);
  const id = int(form, "sm_id");
  const title = str(form, "title");
  const a = int(form, "a_id");
  const b = int(form, "b_id");
  const closes = fromSydneyInput(str(form, "closes_at") ?? "");
  const reward = int(form, "reward") ?? 88;
  const arm = str(form, "arm") === "left" ? "left" : "right";
  if (!title || !a || !b || a === b) done(key, "coins", "Give it a title and two different pullers.", true);
  if (!closes) done(key, "coins", "Set when voting closes.", true);
  try {
    const db = await getDb();
    if (id) {
      await db.query(`UPDATE supermatches SET title=$1, blurb=$2, a_id=$3, b_id=$4, closes_at=$5, reward=$6, arm=$8 WHERE id=$7 AND settled_at IS NULL`, [
        title, str(form, "blurb"), a, b, closes, reward, id, arm,
      ]);
    } else {
      const slug = `${slugify(title)}-${closes.toISOString().slice(0, 10)}`;
      await db.query(`INSERT INTO supermatches (slug, title, blurb, a_id, b_id, closes_at, reward, arm) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`, [
        slug, title, str(form, "blurb"), a, b, closes, reward, arm,
      ]);
    }
  } catch (err) {
    done(key, "coins", friendly(err), true);
  }
  done(key, "coins", id ? "Supermatch updated." : "Supermatch created. It's now featured on /supermatch.");
}

/** Records the winner and pays out: reward to every correct pick, plus stake × the odds locked in at bet time. Runs once. */
export async function settleSupermatch(form: FormData) {
  const key = guard(form);
  const id = int(form, "sm_id");
  const winner = int(form, "winner_id");
  let paid = 0;
  try {
    const db = await getDb();
    const res = await db.transaction(async (tx) => {
      const [m] = await tx.query<{ a_id: number; b_id: number; reward: number; settled_at: string | null }>(
        `SELECT a_id, b_id, reward, settled_at FROM supermatches WHERE id = $1 FOR UPDATE`,
        [id],
      );
      if (!m) return "Supermatch not found.";
      if (m.settled_at) return "Already settled.";
      if (winner !== m.a_id && winner !== m.b_id) return "Pick the winner.";
      await tx.query(`UPDATE supermatches SET winner_id = $2, settled_at = now() WHERE id = $1`, [id, winner]);
      // Chalk for the two pullers (if their Riser is linked to a member account).
      const pullers = await tx.query<{ id: number; account_id: number | null }>(
        `SELECT id, account_id FROM pullers WHERE id IN ($1, $2)`,
        [m.a_id, m.b_id],
      );
      for (const pl of pullers) {
        if (!pl.account_id) continue;
        const won = pl.id === winner;
        await awardChalk(
          tx,
          pl.account_id,
          currentSeason(),
          CHALK.supermatch + (won ? CHALK.supermatchWin : 0),
          won ? "Won a club supermatch" : "Pulled in a club supermatch",
          `sm:${id}:puller`,
        );
      }
      const [pools] = await tx.query<{ a: number; b: number }>(
        `SELECT coalesce(sum(stake) FILTER (WHERE pick_id = $2), 0)::int AS a,
                coalesce(sum(stake) FILTER (WHERE pick_id = $3), 0)::int AS b
         FROM predictions WHERE match_id = $1`,
        [id, m.a_id, m.b_id],
      );
      // Bets placed before odds were locked fall back to the final price.
      const fallback = oddsOf(pools)[winner === m.a_id ? "a" : "b"];
      const right = await tx.query<{ account_id: number; stake: number; odds: number | null }>(
        `SELECT account_id, stake, odds::float8 AS odds FROM predictions WHERE match_id = $1 AND pick_id = $2`,
        [id, winner],
      );
      for (const r of right) {
        await grant(tx, r.account_id, m.reward, "Called the supermatch", `sm:${id}:reward`);
        const odds = r.odds ?? fallback;
        if (r.stake > 0)
          await grant(tx, r.account_id, payoutAt(r.stake, odds), `Supermatch stake paid at ${fmtOdds(odds)}`, `sm:${id}:payout`);
        paid++;
      }
      return null;
    });
    if (res) done(key, "coins", res, true);
  } catch (err) {
    done(key, "coins", friendly(err), true);
  }
  done(key, "coins", `Settled. Paid out to ${paid} ${paid === 1 ? "account" : "accounts"}.`);
}

export async function deleteSupermatch(form: FormData) {
  const key = guard(form);
  const db = await getDb();
  const id = int(form, "sm_id");
  // Refund any stakes before removing an unsettled match.
  await db.transaction(async (tx) => {
    const staked = await tx.query<{ account_id: number; stake: number }>(
      `SELECT p.account_id, p.stake FROM predictions p JOIN supermatches m ON m.id = p.match_id
       WHERE p.match_id = $1 AND p.stake > 0 AND m.settled_at IS NULL`,
      [id],
    );
    for (const r of staked) await grant(tx, r.account_id, r.stake, "Supermatch cancelled: stake refunded", `sm:${id}:refund`);
    await tx.query(`DELETE FROM supermatches WHERE id = $1`, [id]);
  });
  done(key, "coins", "Supermatch removed. Any stakes were refunded.");
}

export async function grantCoins(form: FormData) {
  const key = guard(form);
  const id = int(form, "account_id");
  const raw = str(form, "amount") ?? "";
  const amount = /^-?\d+$/.test(raw) ? Number(raw) : 0;
  if (!id || !amount || Math.abs(amount) > 100000) done(key, "coins", "Enter a whole number of coins (negative to remove).", true);
  const db = await getDb();
  await grant(db, id, amount, str(form, "reason") ?? (amount > 0 ? "Bonus from the club" : "Adjustment"), null);
  done(key, "coins", `${amount > 0 ? "Granted" : "Removed"} ${Math.abs(amount)} coins.`);
}

export async function resetAccountPassword(form: FormData) {
  const key = guard(form);
  const id = int(form, "account_id");
  const pw = str(form, "password") ?? "";
  if (!id || pw.length < 8) done(key, "coins", "New password needs at least 8 characters.", true);
  const db = await getDb();
  await db.query(`UPDATE accounts SET pass_hash = $2 WHERE id = $1`, [id, await hashPassword(pw)]);
  await db.query(`DELETE FROM sessions WHERE account_id = $1`, [id]);
  done(key, "coins", "Password reset. Send it to the member privately and ask them to keep it safe.");
}

export async function setLevel2(form: FormData) {
  const key = guard(form);
  const id = int(form, "account_id");
  const on = bool(form, "on");
  if (!id) done(key, "coins", "Pick an account.", true);
  const db = await getDb();
  await db.query(`INSERT INTO pinrun_wallet (account_id, l2) VALUES ($1, $2) ON CONFLICT (account_id) DO UPDATE SET l2 = $2`, [id, on]);
  done(key, "coins", on ? "Pin Run Level 2 unlocked for that account." : "Level 2 unlock removed (they can still unlock it by scoring 15,000).");
}

export async function makeResetLink(form: FormData) {
  const key = guard(form);
  const id = int(form, "account_id");
  if (!id) done(key, "coins", "Pick an account.", true);
  const token = await createResetToken(id);
  const db = await getDb();
  const [a] = await db.query<{ handle: string }>(`SELECT handle FROM accounts WHERE id = $1`, [id]);
  revalidatePath("/", "layout");
  redirect(`/admin/${encodeURIComponent(key)}?tab=coins&reset_for=${encodeURIComponent(a?.handle ?? "")}&reset=${encodeURIComponent(token)}`);
}

export async function setRedemptionUsed(form: FormData) {
  const key = guard(form);
  const db = await getDb();
  await db.query(`UPDATE redemptions SET fulfilled = $2 WHERE id = $1`, [int(form, "redemption_id"), bool(form, "used")]);
  done(key, "coins", "Updated.");
}

/** Random draw among the open entries for a giveaway item. Each entry is one ticket. */
export async function setGiveawayDate(form: FormData) {
  const key = guard(form);
  const at = fromSydneyInput(str(form, "draw_at") ?? "");
  if (!at) done(key, "coins", "Pick a draw date and time.", true);
  await setGiveawayDrawAt(at.toISOString());
  done(key, "coins", "Giveaway draw date saved.");
}

export async function drawGiveaway(form: FormData) {
  const key = guard(form);
  const item = itemById(str(form, "item") ?? "");
  if (!item || item.kind !== "entry") done(key, "coins", "Unknown giveaway.", true);
  const db = await getDb();
  const [w] = await db.query<{ id: number; display_name: string; handle: string; code: string }>(
    `SELECT r.id, a.display_name, a.handle, r.code FROM redemptions r JOIN accounts a ON a.id = r.account_id
     WHERE r.item = $1 AND NOT r.fulfilled ORDER BY random() LIMIT 1`,
    [item.id],
  );
  if (!w) done(key, "coins", "No open entries to draw from.", true);
  await db.query(`UPDATE redemptions SET won = true WHERE id = $1`, [w.id]);
  // Close out this round: every entry for it is marked used.
  await db.query(`UPDATE redemptions SET fulfilled = true WHERE item = $1 AND NOT fulfilled`, [item.id]);
  done(key, "coins", `Winner: ${w.display_name} (@${w.handle}), ticket ${w.code}. All entries for this round are now closed.`);
}

/* ─────────── Chalk ─────────── */

/** Opens check-in for today (creates today's meet with a fresh code), or reopens it. */
export async function openCheckin(form: FormData) {
  const key = guard(form);
  const tournament = form.get("is_tournament") === "on";
  const db = await getDb();
  await db.query(
    `INSERT INTO meets (day, code, is_tournament) VALUES ($1::date, $2, $3)
     ON CONFLICT (day) DO UPDATE SET open = true, is_tournament = meets.is_tournament OR EXCLUDED.is_tournament`,
    [sydneyToday(), newMeetCode(), tournament],
  );
  done(key, "chalk", "Check-in is open. Show members the code.");
}

export async function setCheckinOpen(form: FormData) {
  const key = guard(form);
  const id = int(form, "meet_id");
  const open = form.get("open") === "1";
  const db = await getDb();
  await db.query(`UPDATE meets SET open = $2 WHERE id = $1`, [id, open]);
  done(key, "chalk", open ? "Check-in reopened." : "Check-in closed.");
}

export async function setMeetTournament(form: FormData) {
  const key = guard(form);
  const id = int(form, "meet_id");
  const db = await getDb();
  await db.query(`UPDATE meets SET is_tournament = NOT is_tournament WHERE id = $1`, [id]);
  done(key, "chalk", "Meet updated.");
}

/** For members who couldn't check in themselves (flat phone, no signal…). */
export async function addAttendee(form: FormData) {
  const key = guard(form);
  const id = int(form, "meet_id");
  const account = int(form, "account_id");
  if (!id || !account) done(key, "chalk", "Pick a member.", true);
  const db = await getDb();
  let added = false;
  await db.transaction(async (tx) => {
    const [meet] = await tx.query<{ id: number; day: string }>(`SELECT id, day::text AS day FROM meets WHERE id = $1`, [id]);
    if (meet) added = await recordCheckin(tx, meet, account);
  });
  done(key, "chalk", added ? `Checked in. +${CHALK.checkin} Chalk.` : "They were already checked in.");
}

/** Sets 1st/2nd/3rd for a tournament meet and re-awards podium Chalk to match. */
export async function setPodium(form: FormData) {
  const key = guard(form);
  const id = int(form, "meet_id");
  const places = [int(form, "first_id"), int(form, "second_id"), int(form, "third_id")];
  const picked = places.filter(Boolean);
  if (new Set(picked).size !== picked.length) done(key, "chalk", "Each place needs a different member.", true);
  const db = await getDb();
  await db.transaction(async (tx) => {
    const [meet] = await tx.query<{ day: string }>(`SELECT day::text AS day FROM meets WHERE id = $1 FOR UPDATE`, [id]);
    if (!meet) return;
    const season = Number(meet.day.slice(0, 4));
    await tx.query(`UPDATE meets SET first_id = $2, second_id = $3, third_id = $4, is_tournament = true WHERE id = $1`, [
      id,
      places[0] ?? null,
      places[1] ?? null,
      places[2] ?? null,
    ]);
    await tx.query(`DELETE FROM chalk_tx WHERE ref LIKE $1`, [`podium:${id}:%`]);
    const label = ["1st", "2nd", "3rd"];
    for (const [i, acct] of places.entries()) {
      if (acct) await awardChalk(tx, acct, season, CHALK.podium[i], `${label[i]} at the ${meetLabel(meet.day)} tournament`, `podium:${id}:${i + 1}`);
    }
  });
  done(key, "chalk", "Podium saved and Chalk awarded.");
}

/** Manual correction, e.g. a missed check-in from an earlier meet. */
export async function adjustChalk(form: FormData) {
  const key = guard(form);
  const account = int(form, "account_id");
  const raw = str(form, "amount") ?? "";
  const amount = /^-?\d{1,4}$/.test(raw) ? Number(raw) : null;
  const reason = str(form, "reason") ?? "Adjusted by the organisers";
  if (!account || !amount) done(key, "chalk", "Pick a member and an amount.", true);
  const db = await getDb();
  await awardChalk(db, account, currentSeason(), amount, reason, null);
  done(key, "chalk", `${amount > 0 ? "Added" : "Removed"} ${Math.abs(amount)} Chalk.`);
}

export async function saveChalkConfig(form: FormData) {
  const key = guard(form);
  const target = int(form, "target");
  if (!target || target < 1 || target > 500) done(key, "chalk", "The Lift target should be between 1 and 500.", true);
  await saveChalkSettings({
    target,
    liftPrize: str(form, "lift_prize") ?? "A season reward from the club",
    topPrize: str(form, "top_prize") ?? "A custom 88 Risers katana: real, sharp, one of one",
  });
  done(key, "chalk", "Chalk settings saved.");
}

/** Links a Riser to their member account (or unlinks with an empty choice). */
export async function linkPullerAccount(form: FormData) {
  const key = guard(form);
  const puller = int(form, "puller_id");
  const account = int(form, "account_id");
  const db = await getDb();
  try {
    await db.query(`UPDATE pullers SET account_id = $2 WHERE id = $1`, [puller, account]);
    if (account && puller) await awardResultsChalk(db, puller);
  } catch (err) {
    done(key, "pullers", /unique|duplicate/i.test(String(err)) ? "That member is already linked to another Riser." : friendly(err), true);
  }
  done(key, "pullers", account ? "Member account linked." : "Member account unlinked.");
}

/** Adds a competition placing to a Riser; a podium pays Chalk to their linked account. */
export async function addResult(form: FormData) {
  const key = guard(form);
  const puller = int(form, "puller_id");
  const event = str(form, "event");
  const place = int(form, "place");
  const date = str(form, "played_on");
  const season = date ? Number(date.slice(0, 4)) : (int(form, "season") ?? currentSeason());
  if (!puller || !event || !place) done(key, "pullers", "Add the competition name and placing.", true);
  const db = await getDb();
  try {
    await db.query(
      `INSERT INTO comp_results (puller_id, event, division, place, played_on, season, notes) VALUES ($1, $2, $3, $4, $5::date, $6, $7)`,
      [puller, event, str(form, "division"), place, date, season, str(form, "notes")],
    );
    await awardResultsChalk(db, puller);
  } catch (err) {
    done(key, "pullers", friendly(err), true);
  }
  done(key, "pullers", place <= 3 ? "Result added. Podium Chalk paid if their member account is linked." : "Result added.");
}

export async function deleteResult(form: FormData) {
  const key = guard(form);
  const id = int(form, "result_id");
  const db = await getDb();
  await db.transaction(async (tx) => {
    await tx.query(`DELETE FROM chalk_tx WHERE ref = $1`, [`result:${id}`]);
    await tx.query(`DELETE FROM comp_results WHERE id = $1`, [id]);
  });
  done(key, "pullers", "Result removed (and its Chalk).");
}

/** Sets (or clears) the Riser number a registration has reserved for a $2 gold coin donation. */
export async function setRequestedId(form: FormData) {
  const key = guard(form);
  const regId = int(form, "registration_id");
  const n = int(form, "requested_id");
  if (n !== null && (n < PICK_MIN || n > PICK_MAX)) done(key, "registrations", `Reserved numbers are #${PICK_MIN}–#${PICK_MAX}.`, true);
  const db = await getDb();
  if (n !== null) {
    const [clash] = await db.query(
      `SELECT 1 FROM pullers WHERE id = $1
       UNION ALL
       SELECT 1 FROM registrations WHERE requested_id = $1 AND id <> $2 AND puller_id IS NULL AND status <> 'archived'`,
      [n, regId],
    );
    if (clash) done(key, "registrations", `#${String(n).padStart(3, "0")} is already taken or reserved.`, true);
  }
  await db.query(`UPDATE registrations SET requested_id = $2, updated_at = now() WHERE id = $1`, [regId, n]);
  done(key, "registrations", n ? `Reserved #${String(n).padStart(3, "0")}.` : "Reservation cleared.");
}
