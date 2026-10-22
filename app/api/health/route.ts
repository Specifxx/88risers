import { getDb } from "@/lib/db";

export const dynamic = "force-dynamic";

/** Uptime check: which region served this, where the database lives, and how quick it answers. */
export async function GET() {
  const host = (process.env.DATABASE_URL || process.env.POSTGRES_URL || "").match(/@([^/:?]+)/)?.[1] ?? "";
  // Neon hosts look like ep-name-123-pooler.<region>.aws.neon.tech; report only the region part.
  const dbRegion = host.match(/\.([a-z]{2}-[a-z]+-\d)\./)?.[1] ?? (host ? "unknown" : "local");
  const t0 = performance.now();
  const db = await getDb();
  const t1 = performance.now();
  const rtts: number[] = [];
  for (let i = 0; i < 3; i++) {
    const s = performance.now();
    await db.query("SELECT 1");
    rtts.push(Math.round(performance.now() - s));
  }
  return Response.json(
    { ok: true, fnRegion: process.env.VERCEL_REGION ?? "local", dbRegion, connectMs: Math.round(t1 - t0), queryMs: rtts },
    { headers: { "cache-control": "no-store" } },
  );
}
