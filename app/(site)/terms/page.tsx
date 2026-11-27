import type { Metadata } from "next";
import Link from "next/link";
import { AFFILIATE_DISCOUNT } from "@/lib/affiliates";
import { MOMENTS_DEPOSIT } from "@/lib/momentsConfig";
import { COMMISSION_SUMMARY, SATCHELS } from "@/lib/shop";
import { SITE } from "@/lib/site";

export const metadata: Metadata = {
  title: "Terms & Refunds",
  description: "The 88 Risers shop, delivery, refunds and returns, 88 Moments, affiliates, events, prizes and coins.",
};

const UPDATED = "28 November 2026";
const pct = (n: number) => `${Math.round(n * 100)}%`;

const SECTIONS: { id: string; title: string; points: React.ReactNode[] }[] = [
  {
    id: "who",
    title: "Who you're dealing with",
    points: [
      <>
        88 Risers is an arm wrestling club in Rhodes, NSW, run as a sole-trader business. Contact:{" "}
        <a href={`mailto:${SITE.email}`}>{SITE.email}</a> or DM <a href={SITE.instagramUrl}>@{SITE.instagramHandle}</a> on Instagram.
      </>,
      "Prices are in Australian dollars. We're not registered for GST, so no GST is charged.",
      "Nothing in these terms limits your rights under the Australian Consumer Law.",
    ],
  },
  {
    id: "shop",
    title: "Shop orders and payment",
    points: [
      "You pay through PayPal (card or PayPal account). Your card details go to PayPal only; we never see them.",
      "Your order is confirmed once PayPal confirms the payment. We email a record of sale from 88risers@gmail.com.",
      "Personalised items (like competition jerseys with your name, nickname and Riser no.) are made to order and take longer. We print exactly what you enter, so check spelling before you pay.",
      "If we can't fill an order (for example, a size runs out), we'll tell you and refund you in full.",
    ],
  },
  {
    id: "delivery",
    title: "Delivery and pickup",
    points: [
      "Pickup at an 88 Risers meet is free. We'll text you when your order is ready.",
      <>
        Postage is by Australia Post prepaid satchel from Doonside NSW, anywhere in Australia, chosen by how many items you order (from{" "}
        ${SATCHELS[0].price.toFixed(2)}). The postage cost is shown before you pay.
      </>,
      "Check your address at checkout. If a parcel is returned because of an incorrect address, we may charge the postage to send it again.",
    ],
  },
  {
    id: "refunds",
    title: "Refunds and returns",
    points: [
      "If an item is faulty, damaged, or not what we described, contact us within a reasonable time and we'll repair, replace or refund it, as the Australian Consumer Law requires. We pay the return postage for faulty items.",
      "We don't offer refunds or returns for change of mind (for example, if you change your mind or pick the wrong size), so please check the size guide and your details before you pay.",
      "Personalised items (with your name, nickname or number) are still covered if they're faulty or printed differently from what you ordered.",
      "Refunds go back through PayPal to how you paid.",
    ],
  },
  {
    id: "moments",
    title: "88 Moments",
    points: [
      "88 Moments is for registered Risers. You book before a competition so we can photograph and film you there.",
      <>
        The ${MOMENTS_DEPOSIT} deposit holds your booking. It comes off your total and is non-refundable if you change your mind or
        don&apos;t turn up. If we don&apos;t cover you at the event, we refund it in full.
      </>,
      "You pay the balance once you approve a preview of your artwork. Printed pieces take about 2–3 weeks; faulty or damaged pieces are replaced.",
      "We may share your artwork on our socials and website. Tell us if you'd rather we didn't.",
    ],
  },
  {
    id: "affiliates",
    title: "Affiliates",
    points: [
      <>
        Anyone can be an affiliate. Buyers who use your code get {pct(AFFILIATE_DISCOUNT)} off the items (not postage), and you earn a
        flat commission of {COMMISSION_SUMMARY} sold with your code.
      </>,
      "Commission counts once an order is paid, and is paid monthly by PayPal or bank transfer to the account you gave us. If you're under 18, a parent or guardian must agree to these terms, and commission is paid to an account they approve. Refunded or cancelled orders don't earn commission, and commission already paid on them may be deducted from your next payment.",
      "You can't use your own code, or have orders placed for yourself under other people's details. We don't pay commission on self-referred or fake orders, and we may close codes that are misused.",
      <>
        <b>You must disclose that you earn commission</b> whenever you share your code or link, for example &ldquo;#ad&rdquo; or
        &ldquo;affiliate code: I earn commission&rdquo;. This is an Australian (ACCC) requirement for paid promotion.
      </>,
      "Don't make claims about our products we haven't made, spam people, or use the 88 Risers name in a misleading way.",
      "Commission is income for you. You're responsible for any tax on it. We may change commission rates for future sales with notice; commission already earned stays as it was.",
    ],
  },
  {
    id: "events",
    title: "Meets, tournaments and prizes",
    points: [
      "Arm wrestling carries a risk of injury. You take part at your own risk and must sign our waiver and follow the referee and our Code of Conduct.",
      "Event details marked as drafts can change; entry details and fees are confirmed before you pay.",
      "Prizes are won by skill. Cash prizes are paid by bank transfer after the event. The Top Riser katana goes to a winner aged 18 or over.",
      "Giveaways and lucky draws have their own terms (how to enter, closing date, draw date) published with each one.",
    ],
  },
  {
    id: "coins",
    title: "Coins, Chalk and games",
    points: [
      "Coins, Temple coins and Chalk are free, earned on the site. They can't be bought, sold or exchanged for cash.",
      "Supermatch picks and games are for fun and prizes from our reward store only. We can correct balances changed by mistakes or misuse.",
    ],
  },
];

export default function TermsPage() {
  return (
    <>
      <section className="page-hero">
        <div className="wrap">
          <p className="crumbs">
            <Link href="/">Home</Link> / Terms &amp; Refunds
          </p>
          <h1 className="display">
            Terms &amp; <span className="gold-text">Refunds.</span>
          </h1>
          <p className="lede">The plain-English rules for buying from us, booking 88 Moments, being an affiliate and competing. Updated {UPDATED}.</p>
          <p className="legal-jump">
            {SECTIONS.map((s) => (
              <a key={s.id} href={`#${s.id}`}>
                {s.title}
              </a>
            ))}
            <Link href="/privacy">Privacy</Link>
          </p>
        </div>
      </section>
      <section className="section" style={{ paddingTop: 32 }}>
        <div className="wrap conduct">
          {SECTIONS.map((s, i) => (
            <div key={s.id} id={s.id} className="panel conduct-rule">
              <span className="conduct-num">{String(i + 1).padStart(2, "0")}</span>
              <div>
                <h2>{s.title}</h2>
                <ul>
                  {s.points.map((p, j) => (
                    <li key={j}>{p}</li>
                  ))}
                </ul>
              </div>
            </div>
          ))}
          <div className="panel conduct-contact">
            <h2>Questions or a problem with an order?</h2>
            <p>
              Email <a href={`mailto:${SITE.email}`}>{SITE.email}</a> with your order number, or DM{" "}
              <a href={SITE.instagramUrl} target="_blank" rel="noreferrer">
                @{SITE.instagramHandle}
              </a>
              . See also our <Link href="/privacy">Privacy policy</Link> and <Link href="/conduct">Code of Conduct</Link>.
            </p>
          </div>
        </div>
      </section>
    </>
  );
}
