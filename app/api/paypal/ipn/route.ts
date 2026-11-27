import { getDb } from "@/lib/db";
import { getShopOrder, markShopOrderPaid } from "@/lib/shopOrders";
import { paypalReceivers } from "@/lib/support";

export const dynamic = "force-dynamic";

const VERIFY = process.env.PAYPAL_SANDBOX ? "https://ipnpb.sandbox.paypal.com/cgi-bin/webscr" : "https://ipnpb.paypal.com/cgi-bin/webscr";

/**
 * PayPal's payment notification (IPN). PayPal posts here when a payment goes through; we send the
 * message straight back to PayPal to confirm it really came from them, then check it's a completed
 * AUD payment to the club for the right amount before marking anything paid. Always answers 200 so
 * PayPal doesn't keep retrying a notice we've deliberately ignored.
 */
export async function POST(req: Request) {
  const body = await req.text();
  const ok = new Response("", { status: 200 });
  let verified = "";
  try {
    const res = await fetch(VERIFY, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded", "User-Agent": "88risers-ipn" },
      body: `cmd=_notify-validate&${body}`,
      signal: AbortSignal.timeout(15000),
    });
    verified = (await res.text()).trim();
  } catch (e) {
    console.error("IPN verify failed", e);
    return new Response("retry", { status: 500 }); // PayPal will resend
  }
  if (verified !== "VERIFIED") {
    console.warn("IPN not verified:", verified.slice(0, 40));
    return ok;
  }
  const f = new URLSearchParams(body);
  const status = f.get("payment_status");
  const ref = f.get("invoice") || f.get("item_number") || "";
  const gross = Number(f.get("mc_gross"));
  const currency = f.get("mc_currency");
  const receiver = (f.get("receiver_email") || f.get("business") || "").toLowerCase();
  const txn = f.get("txn_id");
  const payer = f.get("payer_email");
  if (status !== "Completed" || currency !== "AUD") return ok;
  if (!paypalReceivers().has(receiver)) {
    console.warn("IPN for another receiver", receiver);
    return ok;
  }

  // Shop orders: 88S-<id>
  const shop = /^88S-(\d+)$/.exec(ref);
  if (shop) {
    const o = await getShopOrder(Number(shop[1]));
    if (!o) return ok;
    if (Math.round(gross * 100) !== o.total_cents) {
      console.warn(`IPN amount mismatch for order ${o.id}: paid ${gross}, expected ${o.total_cents / 100}`);
      return ok;
    }
    if (f.get("custom") && f.get("custom") !== o.token) return ok;
    await markShopOrderPaid(o.id, { txn, payer });
    return ok;
  }

  // 88 Moments deposits: 88M-<id>
  const moment = /^88M-(\d+)$/.exec(ref);
  if (moment && gross >= 30) {
    const db = await getDb();
    await db.query(`UPDATE moment_orders SET status = 'deposit' WHERE id = $1 AND status = 'new'`, [Number(moment[1])]);
  }
  return ok;
}
