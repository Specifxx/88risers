import { isAdminKey } from "@/lib/admin";
import { logAuthors, logRows, participantCodes } from "@/lib/trainlog";

export const dynamic = "force-dynamic";

/**
 * Downloads every member's training log for the pioneer study: ?format=txt|csv, and ?anon=1 to
 * replace names with participant codes (P01, P02...). Note: names written inside entries stay.
 */
export async function GET(req: Request, { params }: { params: Promise<{ key: string }> }) {
  const { key } = await params;
  if (!isAdminKey(decodeURIComponent(key))) return new Response("Not found", { status: 404 });
  const url = new URL(req.url);
  const csv = url.searchParams.get("format") === "csv";
  const anon = url.searchParams.get("anon") === "1";
  const [authors, rows] = await Promise.all([logAuthors(), logRows()]);
  const codes = participantCodes(authors);
  const who = (r: { account_id: number; display_name: string; handle: string }) => (anon ? codes.get(r.account_id)! : `${r.display_name} (@${r.handle})`);
  const stamp = new Date().toISOString().slice(0, 10);
  let out: string;
  if (csv) {
    const q = (v: string) => `"${v.replace(/"/g, '""')}"`;
    out = [anon ? "participant,date,entry" : "participant,handle,date,entry", ...rows.map((r) => (anon ? [codes.get(r.account_id)!, r.day, q(r.body)] : [q(r.display_name), r.handle, r.day, q(r.body)]).join(","))].join("\r\n");
  } else {
    const head = `88 Risers pioneer arm wrestling study: training logs${anon ? " (anonymised)" : ""}\n${authors.length} participants, ${rows.length} entries · exported ${stamp}\n`;
    const parts: string[] = [head];
    let last = -1;
    for (const r of rows) {
      if (r.account_id !== last) {
        const a = authors.find((x) => x.account_id === r.account_id)!;
        parts.push(`\n\n########## ${who(r)} · ${a.entries} entries, ${a.first} to ${a.last} ##########\n`);
        last = r.account_id;
      }
      parts.push(`\n===== ${r.day} =====\n${r.body}\n`);
    }
    out = parts.join("");
  }
  return new Response(out, {
    headers: {
      "Content-Type": csv ? "text/csv; charset=utf-8" : "text/plain; charset=utf-8",
      "Content-Disposition": `attachment; filename="88risers-study-logs${anon ? "-anon" : ""}-${stamp}.${csv ? "csv" : "txt"}"`,
      "Cache-Control": "no-store",
    },
  });
}
