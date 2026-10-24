/** Where club donations and sponsorship payments go. */
export const PAYPAL_EMAIL = "georgelu721@gmail.com";

/** A PayPal donate link (card or PayPal, one-off or monthly) for the given purpose and amount. */
export function paypalLink(itemName: string, amount?: number) {
  const q = new URLSearchParams({ business: PAYPAL_EMAIL, currency_code: "AUD", item_name: itemName });
  if (amount) q.set("amount", String(amount));
  return `https://www.paypal.com/donate/?${q}`;
}
