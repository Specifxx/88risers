import "server-only";

/**
 * Where club donations and sponsorship payments go. Kept server-side: pages link to /donate,
 * which redirects to PayPal, so the address never appears in the site's HTML.
 * If PAYPAL_DONATE_BUTTON_ID is set (a Donate button made in PayPal), that is used instead,
 * and PayPal shows the button's name rather than the email address.
 */
const PAYPAL_EMAIL = process.env.PAYPAL_EMAIL || "georgelu721@gmail.com";

export const PURPOSES = {
  funds: "88 Risers club funds",
  sponsor: "88 Risers sponsorship",
} as const;
export type Purpose = keyof typeof PURPOSES;

export function paypalUrl(purpose: Purpose, amount?: number) {
  const button = process.env.PAYPAL_DONATE_BUTTON_ID;
  const q = button
    ? new URLSearchParams({ hosted_button_id: button })
    : new URLSearchParams({ business: PAYPAL_EMAIL, currency_code: "AUD", item_name: PURPOSES[purpose] });
  if (amount) q.set("amount", String(amount));
  return `https://www.paypal.com/donate/?${q}`;
}

/**
 * A PayPal payment (goods, not a donation) for something the club sells, e.g. an 88 Moments deposit.
 * PayPal's standard "Buy Now" link: the buyer pays by card or PayPal, in AUD.
 */
export function paypalPaymentUrl(
  itemName: string,
  amount: number,
  ref: string,
  extra: { notifyUrl?: string; returnUrl?: string; cancelUrl?: string; custom?: string } = {},
) {
  const q = new URLSearchParams({
    cmd: "_xclick",
    business: PAYPAL_EMAIL,
    item_name: itemName,
    item_number: ref,
    amount: amount.toFixed(2),
    currency_code: "AUD",
    no_shipping: "1",
    invoice: ref,
    charset: "utf-8",
  });
  if (extra.notifyUrl) q.set("notify_url", extra.notifyUrl);
  if (extra.returnUrl) q.set("return", extra.returnUrl);
  if (extra.cancelUrl) q.set("cancel_return", extra.cancelUrl);
  if (extra.custom) q.set("custom", extra.custom);
  return `https://www.paypal.com/cgi-bin/webscr?${q}`;
}

/** The on-site link: /donate?for=funds&amount=20 */
export const donateHref = (purpose: Purpose, amount?: number) =>
  `/donate?for=${purpose}${amount ? `&amount=${amount}` : ""}`;

/** Addresses a genuine payment to the club may be addressed to (PayPal reports the receiving account). */
export function paypalReceivers(): Set<string> {
  const extra = (process.env.PAYPAL_RECEIVER_EMAILS || "").split(/[,\s]+/);
  return new Set([PAYPAL_EMAIL, "88risers@gmail.com", ...extra].map((e) => e.trim().toLowerCase()).filter(Boolean));
}
