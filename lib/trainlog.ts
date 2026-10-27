import "server-only";
import { getDb } from "./db";

export type LogAuthor = { account_id: number; display_name: string; handle: string; entries: number; days: number; first: string; last: string };
export type LogRow = { account_id: number; display_name: string; handle: string; day: string; body: string };

/** Everyone who has logged, with counts and date range (for the study admin view). */
export async function logAuthors(): Promise<LogAuthor[]> {
  const db = await getDb();
  return db.query<LogAuthor>(
    `SELECT a.id AS account_id, a.display_name, a.handle, count(*)::int AS entries, count(DISTINCT t.logged_on)::int AS days,
            to_char(min(t.logged_on), 'YYYY-MM-DD') AS first, to_char(max(t.logged_on), 'YYYY-MM-DD') AS last
     FROM training_log t JOIN accounts a ON a.id = t.account_id
     GROUP BY a.id, a.display_name, a.handle ORDER BY min(t.logged_on), a.id`,
  );
}

/** Every entry (optionally one member's), oldest first. */
export async function logRows(handle?: string): Promise<LogRow[]> {
  const db = await getDb();
  return db.query<LogRow>(
    `SELECT a.id AS account_id, a.display_name, a.handle, to_char(t.logged_on, 'YYYY-MM-DD') AS day, t.body
     FROM training_log t JOIN accounts a ON a.id = t.account_id
     ${handle ? "WHERE a.handle = $1" : ""}
     ORDER BY a.id, t.logged_on, t.id`,
    handle ? [handle] : [],
  );
}

/** Study codes (P01, P02...) in the order people started logging, for anonymised exports. */
export function participantCodes(authors: LogAuthor[]) {
  return new Map(authors.map((a, i) => [a.account_id, `P${String(i + 1).padStart(2, "0")}`]));
}
