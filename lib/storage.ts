import "server-only";
import { getDb, scrubDbError, type Db } from "./db";

/**
 * Database storage: what is using space, whether writes still work, and cleanups.
 *
 * Neon's free plan blocks every write (including DELETE) once the project is over its storage
 * limit; reads keep working. The report below is read-only so it still loads in that state.
 * Branches and change history count toward the limit too and are only visible in Neon.
 */

export interface StorageReport {
  dbBytes: number;
  tables: { name: string; bytes: number; rows: number }[];
  photos: { count: number; bytes: number; unused: number; unusedBytes: number };
  expired: { sessions: number; resets: number; loginAttempts: number };
  writable: boolean;
  writeError: string | null;
}

/** Writes a tiny marker row. Fails while the database is over its storage limit. */
async function probeWrite(db: Db): Promise<string | null> {
  try {
    await db.query(
      `INSERT INTO meta (key, value) VALUES ('storage_probe', now()::text) ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value`,
    );
    return null;
  } catch (e) {
    return scrubDbError(e);
  }
}

/** Every photo id that some row still points at, as a set. */
async function usedPhotoIds(db: Db): Promise<Set<string>> {
  const used = new Set<string>();
  for (const r of await db.query<{ id: string }>(`SELECT photo_id::text AS id FROM registrations WHERE photo_id IS NOT NULL`))
    used.add(r.id);
  // Photos are also linked by URL ("/api/photos/<uuid>#focus=…") from any text column. Scan them
  // all rather than a fixed list, so a column added later can never lose its photo to a cleanup.
  const cols = await db.query<{ t: string; c: string }>(
    `SELECT table_name AS t, column_name AS c FROM information_schema.columns
     WHERE table_schema = 'public' AND data_type IN ('text', 'character varying') AND table_name <> 'photos'`,
  );
  for (const { t, c } of cols) {
    const rows = await db.query<{ v: string }>(
      `SELECT "${c.replace(/"/g, '""')}" AS v FROM "${t.replace(/"/g, '""')}" WHERE "${c.replace(/"/g, '""')}" LIKE '%/api/photos/%'`,
    );
    for (const { v } of rows) for (const m of v.matchAll(/\/api\/photos\/([0-9a-f-]{36})/gi)) used.add(m[1].toLowerCase());
  }
  return used;
}

async function unusedPhotos(db: Db) {
  const used = await usedPhotoIds(db);
  const all = await db.query<{ id: string; bytes: number }>(`SELECT id::text AS id, octet_length(data)::int AS bytes FROM photos`);
  return all.filter((p) => !used.has(p.id.toLowerCase()));
}

export async function storageReport(): Promise<StorageReport> {
  const db = await getDb();
  const [[size], tables, [photos], [expired], unused, writeError] = await Promise.all([
    db.query<{ bytes: string }>(`SELECT pg_database_size(current_database())::text AS bytes`),
    db.query<{ name: string; bytes: string; rows: string }>(
      `SELECT c.relname AS name, pg_total_relation_size(c.oid)::text AS bytes, greatest(c.reltuples, 0)::bigint::text AS rows
       FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE c.relkind = 'r' AND n.nspname = 'public'
       ORDER BY pg_total_relation_size(c.oid) DESC LIMIT 10`,
    ),
    db.query<{ count: number; bytes: string }>(`SELECT count(*)::int AS count, coalesce(sum(octet_length(data)), 0)::text AS bytes FROM photos`),
    db.query<{ sessions: number; resets: number; login_attempts: number }>(
      `SELECT (SELECT count(*)::int FROM sessions WHERE expires_at < now()) AS sessions,
              (SELECT count(*)::int FROM password_resets WHERE expires_at < now() OR used_at IS NOT NULL) AS resets,
              (SELECT count(*)::int FROM login_attempts WHERE at < now() - interval '1 day') AS login_attempts`,
    ),
    unusedPhotos(db),
    probeWrite(db),
  ]);
  return {
    dbBytes: Number(size.bytes),
    tables: tables.map((t) => ({ name: t.name, bytes: Number(t.bytes), rows: Number(t.rows) })),
    photos: {
      count: photos.count,
      bytes: Number(photos.bytes),
      unused: unused.length,
      unusedBytes: unused.reduce((s, p) => s + p.bytes, 0),
    },
    expired: { sessions: expired.sessions, resets: expired.resets, loginAttempts: expired.login_attempts },
    writable: writeError === null,
    writeError,
  };
}

/** Deletes photos nothing points at, plus expired logins. Then VACUUM so the space is reusable. */
export async function cleanUpStorage() {
  const db = await getDb();
  const unused = await unusedPhotos(db);
  let photos = 0;
  for (let i = 0; i < unused.length; i += 200) {
    const ids = unused.slice(i, i + 200).map((p) => p.id);
    const r = await db.query(`DELETE FROM photos WHERE id = ANY($1::uuid[]) RETURNING 1`, [ids]);
    photos += r.length;
  }
  const [s] = await db.query<{ n: number }>(`WITH d AS (DELETE FROM sessions WHERE expires_at < now() RETURNING 1) SELECT count(*)::int AS n FROM d`);
  const [p] = await db.query<{ n: number }>(
    `WITH d AS (DELETE FROM password_resets WHERE expires_at < now() OR used_at IS NOT NULL RETURNING 1) SELECT count(*)::int AS n FROM d`,
  );
  const [l] = await db.query<{ n: number }>(
    `WITH d AS (DELETE FROM login_attempts WHERE at < now() - interval '1 day' RETURNING 1) SELECT count(*)::int AS n FROM d`,
  );
  // Plain VACUUM (not FULL): marks the freed space reusable and trims empty pages off the end.
  // VACUUM FULL would need room for a full copy of each table, which a full database doesn't have.
  for (const t of ["photos", "sessions", "password_resets", "login_attempts"]) {
    try {
      await db.query(`VACUUM ${t}`);
    } catch (e) {
      console.error(`VACUUM ${t} failed`, e);
    }
  }
  return { photos, freedBytes: unused.reduce((s, p) => s + p.bytes, 0), sessions: s.n, resets: p.n, loginAttempts: l.n };
}

/** Removes one photo if nothing uses it any more (after a re-upload replaced it). */
export async function deletePhotoIfUnused(db: Db, idOrUrl: string | null | undefined) {
  const id = idOrUrl?.match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i)?.[0];
  if (!id) return;
  const used = await usedPhotoIds(db);
  if (!used.has(id.toLowerCase())) await db.query(`DELETE FROM photos WHERE id = $1`, [id]);
}

export const fmtBytes = (n: number) =>
  n >= 1024 ** 3 ? `${(n / 1024 ** 3).toFixed(2)} GB` : n >= 1024 ** 2 ? `${(n / 1024 ** 2).toFixed(1)} MB` : `${Math.round(n / 1024)} KB`;
