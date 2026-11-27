import "server-only";
import { del, put } from "@vercel/blob";

/**
 * Photo files live in Vercel Blob (file storage), not in Postgres. The database keeps only each
 * photo's row (id, type, public/private) and its Blob address, so it stays small.
 *
 * Every file gets a long random name, and private photos (sign-up photos) are never linked to
 * directly: /api/photos/<id> checks the admin key and fetches the file server-side.
 * Without BLOB_READ_WRITE_TOKEN (local dev, or before the store is connected) photos are kept
 * in the database as before.
 */
// Newer Blob stores connect with BLOB_STORE_ID plus Vercel's built-in OIDC sign-in; older ones with a token.
export const blobEnabled = () => !!(process.env.BLOB_READ_WRITE_TOKEN || process.env.BLOB_STORE_ID);

const EXT: Record<string, string> = { "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp" };

export async function putPhotoFile(id: string, mime: string, data: Uint8Array): Promise<string> {
  const res = await put(`photos/${id}.${EXT[mime] ?? "bin"}`, Buffer.from(data), {
    access: "public",
    addRandomSuffix: true,
    contentType: mime,
    cacheControlMaxAge: 60 * 60 * 24 * 365,
  });
  return res.url;
}

/** Deletes Blob files; failures are logged, never thrown (the rows are already gone). */
export async function deletePhotoFiles(urls: Array<string | null | undefined>) {
  const list = urls.filter((u): u is string => !!u);
  if (!list.length || !blobEnabled()) return;
  try {
    await del(list);
  } catch (e) {
    console.error("blob delete failed", e);
  }
}
