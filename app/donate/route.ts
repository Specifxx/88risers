import { type NextRequest, NextResponse } from "next/server";
import { PURPOSES, type Purpose, paypalUrl } from "@/lib/support";

/** Sends donors on to PayPal without putting the payment address in the page. */
export function GET(req: NextRequest) {
  const p = req.nextUrl.searchParams;
  const purpose: Purpose = (p.get("for") ?? "") in PURPOSES ? (p.get("for") as Purpose) : "funds";
  const amt = Number(p.get("amount"));
  const amount = Number.isInteger(amt) && amt > 0 && amt <= 10000 ? amt : undefined;
  return NextResponse.redirect(paypalUrl(purpose, amount), 302);
}
