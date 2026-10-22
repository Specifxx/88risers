import { searchMembers } from "@/lib/members";

export const dynamic = "force-dynamic";

/** Member search for the Riser Database page (it is static, so it asks here as you type). */
export async function GET(req: Request) {
  const q = new URL(req.url).searchParams.get("q") ?? "";
  const rows = await searchMembers(q);
  return Response.json(rows, { headers: { "cache-control": "no-store" } });
}
