import { getClubStats } from "@/lib/data";

export const dynamic = "force-dynamic";

/** Live Riser-number availability for the join form (the page itself is cached). */
export async function GET() {
  const s = await getClubStats();
  return Response.json({ next: s.next_id, unavailable: s.unavailable }, { headers: { "cache-control": "no-store" } });
}
