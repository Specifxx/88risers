import { NextResponse } from "next/server";
import { getDb } from "@/lib/db";
import { MOMENTS_DEPOSIT } from "@/lib/momentsConfig";
import { paypalPaymentUrl } from "@/lib/support";
import { SITE } from "@/lib/site";

export const dynamic = "force-dynamic";

/** Sends a Riser to PayPal to pay the $30 deposit for their 88 Moments booking. */
export async function GET(req: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const n = /^[0-9]{1,9}$/.test(id) ? Number(id) : null;
  const db = await getDb();
  const [row] = n ? await db.query<{ id: number }>(`SELECT id FROM moment_orders WHERE id = $1`, [n]) : [];
  if (!row) return NextResponse.redirect(new URL("/moments", req.url), 302);
  return NextResponse.redirect(paypalPaymentUrl(`88 Moments deposit, booking #${row.id}`, MOMENTS_DEPOSIT, `88M-${row.id}`, {
      notifyUrl: `${SITE.url.replace(/\/$/, "")}/api/paypal/ipn`,
      returnUrl: `${SITE.url.replace(/\/$/, "")}/moments?paid=${row.id}`,
    }), 302);
}
