"use server";

import { revalidatePath } from "next/cache";
import { currentAccount } from "@/lib/auth";
import { getDb } from "@/lib/db";

/** Longest single entry (plenty for a detailed session write-up). */
const MAX_BODY = 20000;
const isDay = (d: unknown): d is string => typeof d === "string" && /^\d{4}-\d{2}-\d{2}$/.test(d) && !Number.isNaN(Date.parse(`${d}T00:00:00Z`));

export type LogResult = { ok: boolean; message: string };

/** Adds a training log entry for the logged-in member. */
export async function addLogEntry(day: string, body: string): Promise<LogResult> {
  const me = await currentAccount();
  if (!me) return { ok: false, message: "Log in to use your training log." };
  const text = String(body ?? "").trim().slice(0, MAX_BODY);
  if (!text) return { ok: false, message: "Write something first." };
  const db = await getDb();
  await db.query(`INSERT INTO training_log (account_id, logged_on, body) VALUES ($1, coalesce($2::date, CURRENT_DATE), $3)`, [
    me.id,
    isDay(day) ? day : null,
    text,
  ]);
  revalidatePath("/log");
  return { ok: true, message: "Saved." };
}

/** Edits one of your own entries. */
export async function updateLogEntry(id: number, day: string, body: string): Promise<LogResult> {
  const me = await currentAccount();
  if (!me) return { ok: false, message: "Log in first." };
  const text = String(body ?? "").trim().slice(0, MAX_BODY);
  if (!text) return { ok: false, message: "An entry can't be empty. Delete it instead." };
  const db = await getDb();
  await db.query(
    `UPDATE training_log SET body = $3, logged_on = coalesce($4::date, logged_on), updated_at = now() WHERE id = $1 AND account_id = $2`,
    [Math.floor(Number(id)), me.id, text, isDay(day) ? day : null],
  );
  revalidatePath("/log");
  return { ok: true, message: "Updated." };
}

/** Deletes one of your own entries. */
export async function deleteLogEntry(id: number): Promise<LogResult> {
  const me = await currentAccount();
  if (!me) return { ok: false, message: "Log in first." };
  const db = await getDb();
  await db.query(`DELETE FROM training_log WHERE id = $1 AND account_id = $2`, [Math.floor(Number(id)), me.id]);
  revalidatePath("/log");
  return { ok: true, message: "Deleted." };
}
