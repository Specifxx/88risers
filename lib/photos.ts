import "server-only";
import { randomUUID } from "node:crypto";
import { blobEnabled, deletePhotoFiles, putPhotoFile } from "./blob";
import type { Db } from "./db";

const MAX_BYTES = 5 * 1024 * 1024;

function sniff(buf: Uint8Array): string | null {
  if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return "image/jpeg";
  if (buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47) return "image/png";
  if (String.fromCharCode(...buf.slice(0, 4)) === "RIFF" && String.fromCharCode(...buf.slice(8, 12)) === "WEBP")
    return "image/webp";
  return null;
}

export type PhotoResult = { id: string } | { error: string } | null;

/**
 * Stores an uploaded image: the file in Vercel Blob when it's connected (otherwise in Postgres),
 * plus a small row in `photos`. Returns null when no file was provided.
 */
export async function savePhoto(db: Db, file: FormDataEntryValue | null, isPublic: boolean): Promise<PhotoResult> {
  if (!file || typeof file === "string" || file.size === 0) return null;
  if (file.size > MAX_BYTES) return { error: "That photo is too large — please use one under 5 MB." };
  const buf = new Uint8Array(await file.arrayBuffer());
  const mime = sniff(buf);
  if (!mime) return { error: "Please upload a JPG, PNG or WebP photo." };
  if (blobEnabled()) {
    const id = randomUUID();
    const url = await putPhotoFile(id, mime, buf);
    try {
      await db.query(`INSERT INTO photos (id, mime, data, blob_url, is_public) VALUES ($1, $2, NULL, $3, $4)`, [id, mime, url, isPublic]);
    } catch (e) {
      await deletePhotoFiles([url]);
      throw e;
    }
    return { id };
  }
  const [row] = await db.query<{ id: string }>(
    `INSERT INTO photos (mime, data, is_public) VALUES ($1, $2, $3) RETURNING id::text`,
    [mime, Buffer.from(buf), isPublic],
  );
  return { id: row.id };
}

/** Deletes photo rows and their Blob files. */
export async function deletePhotos(db: Db, ids: string[]): Promise<number> {
  if (!ids.length) return 0;
  const rows = await db.query<{ blob_url: string | null }>(`DELETE FROM photos WHERE id = ANY($1::uuid[]) RETURNING blob_url`, [ids]);
  await deletePhotoFiles(rows.map((r) => r.blob_url));
  return rows.length;
}

/**
 * Moves photos still stored in the database into Blob, a batch at a time (so each click stays
 * well inside a request's time limit). Returns how many moved and how many are left.
 */
export async function movePhotosToBlob(db: Db, batch = 40): Promise<{ moved: number; left: number }> {
  if (!blobEnabled()) throw new Error("Vercel Blob isn't connected yet (no BLOB_READ_WRITE_TOKEN).");
  const rows = await db.query<{ id: string; mime: string; data: Uint8Array }>(
    `SELECT id::text AS id, mime, data FROM photos WHERE blob_url IS NULL AND data IS NOT NULL ORDER BY created_at LIMIT $1`,
    [batch],
  );
  let moved = 0;
  for (const r of rows) {
    const url = await putPhotoFile(r.id, r.mime, r.data);
    const done = await db.query(`UPDATE photos SET blob_url = $2, data = NULL WHERE id = $1 AND blob_url IS NULL RETURNING 1`, [r.id, url]);
    if (done.length) moved++;
    else await deletePhotoFiles([url]);
  }
  const [{ n }] = await db.query<{ n: number }>(`SELECT count(*)::int AS n FROM photos WHERE blob_url IS NULL AND data IS NOT NULL`);
  if (n === 0 && moved) {
    try {
      await db.query(`VACUUM photos`); // make the freed space reusable
    } catch (e) {
      console.error("VACUUM photos failed", e);
    }
  }
  return { moved, left: n };
}

export async function photoCounts(db: Db) {
  const [r] = await db.query<{ in_db: number; in_blob: number }>(
    `SELECT count(*) FILTER (WHERE blob_url IS NULL AND data IS NOT NULL)::int AS in_db,
            count(*) FILTER (WHERE blob_url IS NOT NULL)::int AS in_blob FROM photos`,
  );
  return { inDb: r.in_db, inBlob: r.in_blob };
}

export const photoUrl = (id: string) => `/api/photos/${id}`;
