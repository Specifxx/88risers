"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { assertAdmin } from "@/lib/admin";
import { recomputeElo } from "@/lib/data";
import { getDb, type Db } from "@/lib/db";
import { savePhoto, photoUrl } from "@/lib/photos";
import { fromSydneyInput } from "@/lib/schedule";
import { videoEmbed } from "@/lib/video";

type Tab = "registrations" | "pullers" | "matches" | "events" | "tv";

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
  const [r] = await db.query<{ n: number }>(`SELECT coalesce(max(id), 0)::int + 1 AS n FROM pullers`);
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
  done(key, "matches", id ? "Match updated — ratings recalculated." : "Match recorded — ratings updated.");
}

export async function deleteMatch(form: FormData) {
  const key = guard(form);
  const db = await getDb();
  await db.transaction(async (tx) => {
    await tx.query(`DELETE FROM matches WHERE id = $1`, [int(form, "match_id")]);
    await recomputeElo(tx);
  });
  done(key, "matches", "Match deleted — ratings recalculated.");
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

export async function deleteReel(form: FormData) {
  const key = guard(form);
  const db = await getDb();
  await db.query(`DELETE FROM tv_reels WHERE id = $1`, [int(form, "reel_id")]);
  done(key, "tv", "Reel removed.");
}
