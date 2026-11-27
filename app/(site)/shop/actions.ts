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
