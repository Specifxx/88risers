import { cookies } from "next/headers";

export const dynamic = "force-dynamic";

/** Is this visitor logged in? Used by the corner lion to decide whether to nudge sign-ups. */
export async function GET() {
  const loggedIn = !!(await cookies()).get("88r_session")?.value;
  return Response.json({ loggedIn }, { headers: { "cache-control": "no-store" } });
}
