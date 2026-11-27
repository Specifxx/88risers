import "server-only";
import { randomBytes } from "node:crypto";
import { getDb } from "./db";
import { sendClubMail } from "./mail";
import { normalisePhone } from "./phone";
import { COMMISSION_SUMMARY } from "./shop";
import { SITE } from "./site";

/**
 * Affiliates: anyone can sign up for a code (no account needed). Buyers who use it get
 * AFFILIATE_DISCOUNT off the items (not postage), and the affiliate earns a flat commission per
 * item (set on each product in lib/shop: $7 per tee, $10 per jersey). Commission counts once the order is paid; the club pays it out
 * monthly. Each affiliate gets a private dashboard link (/affiliates?t=…), emailed to them.
 * An affiliate can't use their own code (matched on their email or mobile).
 */
export const AFFILIATE_DISCOUNT = 0.1;

export type Affiliate = {
  id: number;
  code: string;
  name: string;
  payout_email: string;
  phone: string;
  token: string;
  active: boolean;
  created_at: Date;
};

export const cleanCode = (c: unknown) =>
  String(c ?? "")
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, "")
    .slice(0, 15);

const base = () => SITE.url.replace(/\/$/, "");
export const dashboardUrl = (a: Pick<Affiliate, "token">) => `${base()}/affiliates?t=${a.token}`;
export const shareUrl = (a: Pick<Affiliate, "code">) => `${base()}/shop?ref=${a.code}`;

export async function affiliateByCode(code: string): Promise<Affiliate | null> {
  const c = cleanCode(code);
  if (c.length < 3) return null;
  const db = await getDb();
  const [a] = await db.query<Affiliate>(`SELECT * FROM affiliates WHERE code = $1 AND active`, [c]);
  return a ?? null;
}

export async function affiliateByToken(token: string): Promise<Affiliate | null> {
  if (!/^[a-f0-9]{32}$/.test(token)) return null;
  const db = await getDb();
  const [a] = await db.query<Affiliate>(`SELECT * FROM affiliates WHERE token = $1`, [token]);
  return a ?? null;
}

async function emailDashboard(a: Affiliate) {
  try {
    await sendClubMail({
      to: a.payout_email,
      subject: `Your 88 Risers affiliate code: ${a.code}`,
      text: [
        `Hi ${a.name.split(" ")[0]},`,
        "",
        `Your affiliate code is ${a.code}.`,
        `Share this link (it fills your code in): ${shareUrl(a)}`,
        "",
        `Buyers get ${AFFILIATE_DISCOUNT * 100}% off, and you earn ${COMMISSION_SUMMARY} they buy.`,
        `See your sales and commission any time (keep this link private): ${dashboardUrl(a)}`,
        "",
        "Commission is paid monthly to this PayPal email for paid, un-refunded orders.",
        "",
        "88 Risers Arm Wrestling Club",
      ].join("\n"),
      replyTo: SITE.email,
    });
  } catch (e) {
    console.error("affiliate email failed", e);
  }
}

/** Signs someone up. Returns their affiliate record (with the private token) or an error. */
export async function joinAffiliates(input: { name: string; code: string; email: string; phone: string }) {
  const name = String(input.name ?? "").trim().replace(/\s+/g, " ").slice(0, 80);
  const code = cleanCode(input.code);
  const email = String(input.email ?? "").trim().toLowerCase().slice(0, 120);
  const phone = normalisePhone(String(input.phone ?? ""));
  if (name.length < 2) return { error: "Tell us your name." };
  if (code.length < 3) return { error: "Codes are 3–15 letters or numbers, e.g. HARRY or LUIE07." };
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return { error: "Add the PayPal email we should pay your commission to." };
  if (!phone) return { error: "Add your mobile number." };
  const db = await getDb();
  const [mine] = await db.query<Affiliate>(`SELECT * FROM affiliates WHERE payout_email = $1`, [email]);
  if (mine) {
    await emailDashboard(mine);
    return { error: `You're already an affiliate (code ${mine.code}). We've emailed your dashboard link again.` };
  }
  const [taken] = await db.query(`SELECT 1 FROM affiliates WHERE code = $1`, [code]);
  if (taken) return { error: `${code} is taken. Try another code.` };
  const token = randomBytes(16).toString("hex");
  const [a] = await db.query<Affiliate>(
    `INSERT INTO affiliates (code, name, payout_email, phone, token) VALUES ($1, $2, $3, $4, $5) RETURNING *`,
    [code, name, email, phone, token],
  );
  await emailDashboard(a);
  return { affiliate: a };
}

/** "Lost my link": emails the dashboard link if that email is an affiliate (says the same either way). */
export async function resendDashboard(emailRaw: string) {
  const email = String(emailRaw ?? "").trim().toLowerCase();
  const db = await getDb();
  const [a] = await db.query<Affiliate>(`SELECT * FROM affiliates WHERE payout_email = $1`, [email]);
  if (a) await emailDashboard(a);
}

/** Totals for an affiliate's dashboard. */
export async function affiliateStats(id: number) {
  const db = await getDb();
  const [s] = await db.query<{ orders: number; items: number; earned: number; paid: number }>(
    `SELECT count(*) FILTER (WHERE status IN ('paid','sent','collected'))::int AS orders,
            coalesce(sum(items_count) FILTER (WHERE status IN ('paid','sent','collected')), 0)::int AS items,
            coalesce(sum(commission_cents) FILTER (WHERE status IN ('paid','sent','collected')), 0)::int AS earned,
            coalesce(sum(commission_cents) FILTER (WHERE status IN ('paid','sent','collected') AND commission_paid_at IS NOT NULL), 0)::int AS paid
     FROM shop_orders WHERE affiliate_id = $1`,
    [id],
  );
  return { ...s, owed: s.earned - s.paid };
}

/** Everyone's totals, for admin. */
export async function affiliateLedger() {
  const db = await getDb();
  return db.query<Affiliate & { orders: number; earned: number; owed: number }>(
    `SELECT a.*,
            count(o.id) FILTER (WHERE o.status IN ('paid','sent','collected'))::int AS orders,
            coalesce(sum(o.commission_cents) FILTER (WHERE o.status IN ('paid','sent','collected')), 0)::int AS earned,
            coalesce(sum(o.commission_cents) FILTER (WHERE o.status IN ('paid','sent','collected') AND o.commission_paid_at IS NULL), 0)::int AS owed
     FROM affiliates a LEFT JOIN shop_orders o ON o.affiliate_id = a.id
     GROUP BY a.id ORDER BY owed DESC, a.created_at DESC`,
  );
}
