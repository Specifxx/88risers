import { isAdminKey } from "@/lib/admin";
import { prettyPhone } from "@/lib/phone";
import { ARMS_LABEL, OPEN, classLabel, openEntries } from "@/lib/rhodesOpen";

export const dynamic = "force-dynamic";

/** Every Rhodes Open entry as a spreadsheet (for brackets, texting and check-in). */
export async function GET(_req: Request, { params }: { params: Promise<{ key: string }> }) {
  const { key } = await params;
  if (!isAdminKey(decodeURIComponent(key))) return new Response("Not found", { status: 404 });
  const q = (v: string | number | null) => `"${String(v ?? "").replace(/"/g, '""')}"`;
  const rows = (await openEntries()).map((e) =>
    [e.name, ARMS_LABEL[e.arms], classLabel(e.weight_class), prettyPhone(e.phone), e.riser_id ?? "", e.instagram ? `@${e.instagram}` : "", e.email, e.notes, new Date(e.created_at).toISOString()].map(q).join(","),
  );
  const csv = ["name,arm,class,mobile,riser_id,instagram,email,notes,entered_at", ...rows].join("\r\n");
  return new Response("﻿" + csv, {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="${OPEN.slug}-entries.csv"`,
      "Cache-Control": "no-store",
    },
  });
}
