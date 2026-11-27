"use server";

import { type CheckoutInput, createShopOrder } from "@/lib/shopOrders";

/** Checks the cart against real prices, saves the order and returns the PayPal link. */
export async function startCheckout(input: CheckoutInput): Promise<{ ok: true; url: string } | { ok: false; message: string }> {
  try {
    const r = await createShopOrder(input);
    if ("error" in r) return { ok: false, message: r.error ?? "Something went wrong." };
    return { ok: true, url: r.url };
  } catch (e) {
    console.error("checkout failed", e);
    return { ok: false, message: "Something went wrong on our side. Try again, or DM us on Instagram." };
  }
}

/** Checks an affiliate code at checkout so the buyer sees the discount before paying. */
export async function checkCode(code: string): Promise<{ ok: true; code: string; percent: number } | { ok: false; message: string }> {
  const { AFFILIATE_DISCOUNT, affiliateByCode, cleanCode } = await import("@/lib/affiliates");
  const c = cleanCode(code);
  if (!c) return { ok: false, message: "Type a code first." };
  const a = await affiliateByCode(c);
  return a ? { ok: true, code: c, percent: Math.round(AFFILIATE_DISCOUNT * 100) } : { ok: false, message: `${c} isn't a valid code.` };
}
