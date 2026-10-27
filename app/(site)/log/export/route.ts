import { currentAccount } from "@/lib/auth";
import { getDb } from "@/lib/db";

export const dynamic = "force-dynamic";

/**
 * Downloads your whole training log, oldest first: ?format=txt (easy to read, or paste into an AI
 * to look for patterns) or ?format=csv (for a spreadsheet).
 */
export async function GET(req: Request) {
  const me = await currentAccount();
  if (!me) return new Response("Log in to download your training log.", { status: 401 });
  const format = new URL(req.url).searchParams.get("format") === "csv" ? "csv" : "txt";
  const db = await getDb();
  const rows = await db.query<{ day: string; body: string; created_at: string }>(
    `SELECT to_char(logged_on, 'YYYY-MM-DD') AS day, body, created_at FROM training_log WHERE account_id = $1 ORDER BY logged_on ASC, id ASC`,
    [me.id],
  );
  const stamp = new Date().toISOString().slice(0, 10);
  let out: string;
  if (format === "csv") {
    const q = (v: string) => `"${v.replace(/"/g, '""')}"`;
    out = ["date,entry", ...rows.map((r) => `${r.day},${q(r.body)}`)].join("\r\n");
  } else {
    const head = `88 Risers training log: ${me.display_name} (@${me.handle})\n${rows.length} entries${rows.length ? `, ${rows[0].day} to ${rows[rows.length - 1].day}` : ""}\nExported ${stamp}\n`;
    out = [head, ...rows.map((r) => `\n===== ${r.day} =====\n${r.body}\n`)].join("");
  }
  return new Response(out, {
    headers: {
      "Content-Type": format === "csv" ? "text/csv; charset=utf-8" : "text/plain; charset=utf-8",
      "Content-Disposition": `attachment; filename="88risers-training-log-${stamp}.${format}"`,
      "Cache-Control": "no-store",
    },
  });
}
