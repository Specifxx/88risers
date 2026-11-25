import { isAdminKey } from "@/lib/admin";
import { MIGRATION_TARGET, dbHealth, getDb, scrubDbError } from "@/lib/db";

export const dynamic = "force-dynamic";

/**
 * Admin-only database health check: /api/db-status?k=<ADMIN_KEY>. Shows whether the database
 * answers, which setup version it has reached, and the last error on this server instance.
 * Never shows connection strings.
 */
export async function GET(req: Request) {
  const k = new URL(req.url).searchParams.get("k");
  if (!isAdminKey(k)) return new Response("Not found", { status: 404 });
  const out: Record<string, unknown> = { target: MIGRATION_TARGET() };
  try {
    const db = await getDb();
    out.connected = true;
    try {
      const rows = await db.query<{ key: string }>(`SELECT key FROM meta WHERE key LIKE 'founders_v%'`);
      const versions = rows.map((r) => Number(r.key.replace("founders_v", ""))).filter((n) => !Number.isNaN(n));
      out.reached = versions.length ? `founders_v${Math.max(...versions)}` : null;
    } catch (e) {
      out.queryError = scrubDbError(e);
    }
  } catch (e) {
    out.connected = false;
    out.error = scrubDbError(e);
  }
  out.migrationError = dbHealth.migrationError;
  out.connectError = dbHealth.connectError;
  return Response.json(out, { headers: { "cache-control": "no-store" } });
}
