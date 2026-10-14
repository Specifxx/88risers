import "server-only";
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

/** Stores an uploaded image in Postgres. Returns null when no file was provided. */
export async function savePhoto(db: Db, file: FormDataEntryValue | null, isPublic: boolean): Promise<PhotoResult> {
  if (!file || typeof file === "string" || file.size === 0) return null;
  if (file.size > MAX_BYTES) return { error: "That photo is too large — please use one under 5 MB." };
  const buf = new Uint8Array(await file.arrayBuffer());
  const mime = sniff(buf);
  if (!mime) return { error: "Please upload a JPG, PNG or WebP photo." };
  const [row] = await db.query<{ id: string }>(
    `INSERT INTO photos (mime, data, is_public) VALUES ($1, $2, $3) RETURNING id::text`,
    [mime, Buffer.from(buf), isPublic],
  );
  return { id: row.id };
}

export const photoUrl = (id: string) => `/api/photos/${id}`;
