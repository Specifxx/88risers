import { listRegistrations } from "@/lib/data";
import { isAdminKey } from "@/lib/admin";

const cell = (v: unknown) => {
  const s = v == null ? "" : String(v);
  // Quote, and neutralise spreadsheet formula injection.
  return `"${(/^[=+\-@]/.test(s) && !/^\+\d+$/.test(s) ? "'" + s : s).replace(/"/g, '""')}"`;
};

/** CSV of everyone who registered — import it into your SMS tool. */
export async function GET(req: Request) {
  if (!isAdminKey(new URL(req.url).searchParams.get("k"))) return new Response("Not found", { status: 404 });
  const rows = await listRegistrations();
  const header = ["name", "phone", "instagram", "status", "riser_id", "registered_at"];
  const lines = rows.map((r) =>
    [r.name, r.phone, r.instagram, r.status, r.puller_id, r.created_at.toISOString()].map(cell).join(","),
  );
  return new Response([header.join(","), ...lines].join("\n"), {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="88risers-registrations.csv"`,
      "Cache-Control": "no-store",
    },
  });
}
