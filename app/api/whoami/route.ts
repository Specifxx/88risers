import { currentAccount } from "@/lib/auth";

export const dynamic = "force-dynamic";

/** Whether this browser is logged in (the header uses it to label the account button). */
export async function GET() {
  const me = await currentAccount();
  return Response.json({ in: !!me }, { headers: { "Cache-Control": "no-store" } });
}
