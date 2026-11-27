import "server-only";
import { randomBytes } from "node:crypto";
import { AFFILIATE_DISCOUNT, affiliateByCode, cleanCode } from "./affiliates";
import { getDb } from "./db";
import { sendClubMail } from "./mail";
import { normalisePhone, prettyPhone } from "./phone";
import { type CartLine, PRODUCTS, SIZES, SLEEVES, lineLabel, money, shippingFor } from "./shop";
import { SITE } from "./site";
import { paypalPaymentUrl } from "./support";

/**
 * Shop orders: the cart is checked against the real prices here (never trusted from the browser),
 * saved as "pending", and the buyer is sent to PayPal. PayPal's payment notification (IPN) then
 * marks it paid and the receipts go out: one to the buyer, one to the club inbox.
 */
export type ShopOrder = {
  id: number;
  token: string;
  name: string;
  email: string;
  phone: string;
  items: string;
  delivery: "pickup" | "post";
  address: string | null;
  shipping_label: string | null;
  subtotal_cents: number;
  shipping_cents: number;
  total_cents: number;
  status: string;
  paypal_txn: string | null;
  payer_email: string | null;
  paid_at: Date | null;
  receipts_sent: boolean;
  notes: string | null;
  created_at: Date;
  promo_code: string | null;
  affiliate_id: number | null;
  discount_cents: number;
  commission_cents: number;
  commission_paid_at: Date | null;
  items_count: number;
};

export type CheckoutInput = {
  lines: CartLine[];
  name: string;
  email: string;
  phone: string;
  delivery: string;
  address?: { line1?: string; line2?: string; suburb?: string; state?: string; postcode?: string };
  notes?: string;
  code?: string;
};

const STATES = ["NSW", "VIC", "QLD", "WA", "SA", "TAS", "ACT", "NT"];
const clean = (v: unknown, max: number) => String(v ?? "").trim().replace(/\s+/g, " ").slice(0, max);
export const ref = (id: number) => `88S-${id}`;
export const cents = (n: number) => Math.round(n * 100);
export const dollars = (c: number) => money(c / 100);

/** Validates a checkout and returns the cleaned order, or an error message for the buyer. */
export function validateCheckout(input: CheckoutInput) {
  const name = clean(input.name, 80);
  const email = clean(input.email, 120).toLowerCase();
  const phone = normalisePhone(clean(input.phone, 30));
  if (name.length < 2) return { error: "Tell us your full name." } as const;
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return { error: "We need a valid email for your receipt." } as const;
  if (!phone) return { error: "That mobile number doesn't look right." } as const;
  const lines: CartLine[] = [];
  for (const raw of Array.isArray(input.lines) ? input.lines.slice(0, 20) : []) {
    const p = PRODUCTS.find((x) => x.id === raw?.product);
    if (!p?.buy) return { error: "Something in your cart isn't for sale any more. Remove it and try again." } as const;
    const size = clean(raw.size, 4);
    const sleeve = clean(raw.sleeve, 10);
    const qty = Math.floor(Number(raw.qty));
    if (!(SIZES as readonly string[]).includes(size)) return { error: `Pick a size for the ${p.name}.` } as const;
    if (!(SLEEVES as readonly string[]).includes(sleeve)) return { error: `Pick raglan or flat sleeve for the ${p.name}.` } as const;
    if (!(qty >= 1 && qty <= 10)) return { error: "Quantities are 1 to 10." } as const;
    const line: CartLine = { product: p.id, size, sleeve, qty };
    if (p.buy.personalise) {
      line.name = clean(raw.name, 20).toUpperCase();
      line.nickname = clean(raw.nickname, 20);
      line.riserNo = clean(raw.riserNo, 4).replace(/^#/, "");
      if (!line.name) return { error: `Add the name for the back of your ${p.name}.` } as const;
      if (line.riserNo && !/^\d{1,3}$/.test(line.riserNo)) return { error: "Riser numbers are up to 3 digits, like 017." } as const;
    }
    lines.push(line);
  }
  if (!lines.length) return { error: "Your cart is empty." } as const;
  const count = lines.reduce((n, l) => n + l.qty, 0);
  const subtotal = lines.reduce((n, l) => n + cents(PRODUCTS.find((x) => x.id === l.product)!.buy!.price) * l.qty, 0);
  let address: string | null = null;
  let ship = { label: "Pickup at an 88 Risers meet", price: 0 };
  if (input.delivery === "post") {
    const a = input.address ?? {};
    const line1 = clean(a.line1, 100);
    const line2 = clean(a.line2, 100);
    const suburb = clean(a.suburb, 60);
    const state = clean(a.state, 3).toUpperCase();
    const postcode = clean(a.postcode, 4);
    if (!line1 || !suburb) return { error: "Add your street address and suburb for postage." } as const;
    if (!STATES.includes(state)) return { error: "Pick your state." } as const;
    if (!/^\d{4}$/.test(postcode)) return { error: "Postcodes are 4 digits." } as const;
    address = [line1, line2, `${suburb} ${state} ${postcode}`].filter(Boolean).join("\n");
    ship = shippingFor(count);
  } else if (input.delivery !== "pickup") {
    return { error: "Choose pickup or postage." } as const;
  }
  return {
    order: {
      name,
      email,
      phone,
      lines,
      delivery: input.delivery as "pickup" | "post",
      address,
      shippingLabel: ship.label,
      subtotal,
      shipping: cents(ship.price),
      total: subtotal + cents(ship.price),
      notes: clean(input.notes, 300) || null,
    },
  } as const;
}

/** Saves the order and returns where to send the buyer to pay. */
export async function createShopOrder(input: CheckoutInput) {
  const v = validateCheckout(input);
  if ("error" in v) return { error: v.error };
  const o = v.order;
  const promo = await applyCode(input.code, o.email, o.phone, o.subtotal, o.lines);
  if ("error" in promo) return { error: promo.error };
  const total = o.subtotal - promo.discount + o.shipping;
  const items = o.lines.reduce((n, l) => n + l.qty, 0);
  const token = randomBytes(12).toString("hex");
  const db = await getDb();
  const [row] = await db.query<{ id: number }>(
    `INSERT INTO shop_orders (token, name, email, phone, items, delivery, address, shipping_label, subtotal_cents, shipping_cents, total_cents, notes,
                              promo_code, affiliate_id, discount_cents, commission_cents, items_count)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17) RETURNING id`,
    [token, o.name, o.email, o.phone, JSON.stringify(o.lines), o.delivery, o.address, o.shippingLabel, o.subtotal, o.shipping, total, o.notes,
     promo.code, promo.affiliate, promo.discount, promo.commission, items],
  );
  const base = SITE.url.replace(/\/$/, "");
  const url = paypalPaymentUrl(`88 Risers order #${row.id}`, total / 100, ref(row.id), {
    notifyUrl: `${base}/api/paypal/ipn`,
    returnUrl: `${base}/shop/thanks?o=${row.id}&t=${token}`,
    cancelUrl: `${base}/shop?cancelled=${row.id}`,
    custom: token,
  });
  return { id: row.id, token, url };
}

/**
 * An affiliate code: AFFILIATE_DISCOUNT off the items for the buyer, and a flat commission per item
 * (each product's buy.commission) to the affiliate. Not usable on your own code.
 */
export async function applyCode(raw: string | undefined, email: string, phone: string | null, subtotal: number, lines: CartLine[]) {
  const code = cleanCode(raw);
  if (!code) return { code: null, affiliate: null, discount: 0, commission: 0 };
  const a = await affiliateByCode(code);
  if (!a) return { error: `${code} isn't a valid code.` };
  if (a.payout_email === email.toLowerCase() || (phone && a.phone === phone)) return { error: "You can't use your own affiliate code." };
  const discount = Math.round(subtotal * AFFILIATE_DISCOUNT);
  const commission = lines.reduce((n, l) => n + cents(PRODUCTS.find((p) => p.id === l.product)?.buy?.commission ?? 0) * l.qty, 0);
  return { code, affiliate: a.id, discount, commission };
}

export async function getShopOrder(id: number, token?: string): Promise<ShopOrder | null> {
  const db = await getDb();
  const [o] = await db.query<ShopOrder>(`SELECT * FROM shop_orders WHERE id = $1`, [id]);
  if (!o || (token !== undefined && o.token !== token)) return null;
  return o;
}

export const orderLines = (o: ShopOrder): CartLine[] => {
  try {
    return JSON.parse(o.items);
  } catch {
    return [];
  }
};

/** The record of sale, as plain text (used for both emails). */
export function receiptText(o: ShopOrder, forClub: boolean) {
  const lines = orderLines(o);
  const rows = lines.map((l) => {
    const price = PRODUCTS.find((p) => p.id === l.product)?.buy?.price ?? 0;
    return `  ${l.qty} x ${lineLabel(l)}  ${money(price * l.qty)}`;
  });
  return [
    forClub ? `New paid order #${o.id} on ${SITE.url.replace(/^https?:\/\//, "")}` : `Thanks for your order, ${o.name.split(" ")[0]}!`,
    "",
    `Order #${o.id} · ${ref(o.id)}`,
    `Paid ${o.paid_at ? new Date(o.paid_at).toLocaleString("en-AU", { timeZone: SITE.timeZone }) : ""} via PayPal${o.paypal_txn ? ` (transaction ${o.paypal_txn})` : ""}`,
    "",
    ...rows,
    "",
    `  Subtotal  ${dollars(o.subtotal_cents)}`,
    o.discount_cents ? `  Code ${o.promo_code}  -${dollars(o.discount_cents)}` : "",
    `  ${o.delivery === "post" ? o.shipping_label || "Postage" : "Pickup at an 88 Risers meet"}  ${o.shipping_cents ? dollars(o.shipping_cents) : "free"}`,
    `  Total paid  ${dollars(o.total_cents)} AUD`,
    "",
    o.delivery === "post" ? `Posting to:\n${o.name}\n${o.address}` : "Pick it up at the next 88 Risers meet. We'll text you when it's ready.",
    "",
    forClub ? `Buyer: ${o.name} · ${o.email} · ${prettyPhone(o.phone)}${o.payer_email && o.payer_email !== o.email ? ` · PayPal ${o.payer_email}` : ""}` : "",
    o.notes ? `Notes: ${o.notes}` : "",
    forClub ? "" : "Made-to-order items (like personalised jerseys) take a little longer; we'll keep you posted.\nQuestions? Reply to this email or DM @88risers_ on Instagram.\n\n88 Risers Arm Wrestling Club",
  ]
    .filter((l, i, a) => !(l === "" && a[i - 1] === ""))
    .join("\n");
}

/** Sends the buyer's receipt and the club's copy. Returns whether email is set up. */
export async function sendReceipts(o: ShopOrder) {
  const club = await sendClubMail({ subject: `Paid order #${o.id}: ${o.name}, ${dollars(o.total_cents)}`, text: receiptText(o, true), replyTo: o.email });
  if (!club) return false;
  await sendClubMail({ to: o.email, subject: `Your 88 Risers order #${o.id}`, text: receiptText(o, false), replyTo: SITE.email });
  const db = await getDb();
  await db.query(`UPDATE shop_orders SET receipts_sent = true WHERE id = $1`, [o.id]);
  return true;
}

/** Marks an order paid once (PayPal can notify more than once) and sends the receipts. */
export async function markShopOrderPaid(id: number, pay: { txn: string | null; payer: string | null }) {
  const db = await getDb();
  const [o] = await db.query<ShopOrder>(
    `UPDATE shop_orders SET status = 'paid', paid_at = now(), paypal_txn = coalesce($2, paypal_txn), payer_email = coalesce($3, payer_email)
     WHERE id = $1 AND status = 'pending' RETURNING *`,
    [id, pay.txn, pay.payer],
  );
  if (!o) return false;
  // Self-referral check at payment time: if the PayPal account that paid belongs to the affiliate
  // whose code was used, no commission (the buyer keeps the discount; the order stands).
  if (o.affiliate_id && o.commission_cents && pay.payer) {
    const [aff] = await db.query<{ payout_email: string }>(`SELECT payout_email FROM affiliates WHERE id = $1`, [o.affiliate_id]);
    if (aff && aff.payout_email === pay.payer.trim().toLowerCase()) {
      await db.query(`UPDATE shop_orders SET commission_cents = 0, notes = trim(coalesce(notes, '') || ' [No commission: paid from the affiliate''s own PayPal]') WHERE id = $1`, [id]);
    }
  }
  try {
    await sendReceipts(o);
  } catch (e) {
    console.error("receipt email failed", e);
  }
  return true;
}
