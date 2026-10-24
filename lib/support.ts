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

/** The on-site link: /donate?for=funds&amount=20 */
export const donateHref = (purpose: Purpose, amount?: number) =>
  `/donate?for=${purpose}${amount ? `&amount=${amount}` : ""}`;
