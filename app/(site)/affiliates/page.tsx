import type { Metadata } from "next";
import Link from "next/link";
import { AffiliateJoin, AffiliateResend } from "@/components/AffiliateJoin";
import { CopyText } from "@/components/CopyText";
import { AFFILIATE_DISCOUNT, affiliateByToken, affiliateStats, shareUrl } from "@/lib/affiliates";
import { COMMISSION_SUMMARY, money } from "@/lib/shop";

export const dynamic = "force-dynamic";
export const metadata: Metadata = {
  title: "Affiliates",
  description: `Share your 88 Risers code: your people get ${AFFILIATE_DISCOUNT * 100}% off club gear and you earn ${COMMISSION_SUMMARY} sold. Anyone can join.`,
};

const pct = (n: number) => `${Math.round(n * 100)}%`;

export default async function AffiliatesPage({ searchParams }: PageProps<"/affiliates">) {
  const sp = await searchParams;
  const aff = typeof sp.t === "string" ? await affiliateByToken(sp.t) : null;
  const stats = aff ? await affiliateStats(aff.id) : null;
  return (
    <section className="page-hero" style={{ paddingBottom: 90 }}>
      <div className="wrap join-grid">
        <div>
          <p className="crumbs">
            <Link href="/shop">Shop</Link> / Affiliates
          </p>
          <h1 className="display">
            Rep it. <span className="gold-text">Earn it.</span>
          </h1>
          <p className="lede">
            Get your own code for the 88 Risers shop. Anyone who uses it gets <b>{pct(AFFILIATE_DISCOUNT)} off</b>, and you earn{" "}
            <b>{COMMISSION_SUMMARY}</b> they buy. Anyone can join.
          </p>
          <ol className="join-steps">
            <li>
              <strong>Get your code</strong>
              Pick a code and tell us where to pay you. Takes a minute.
            </li>
            <li>
              <strong>Share it</strong>
              Your link fills the code in for them, or they type it at checkout.
            </li>
            <li>
              <strong>Get paid</strong>
              Commission on every paid order, sent to your PayPal monthly.
            </li>
          </ol>
          <p className="fine">
            Commission is a flat {COMMISSION_SUMMARY} sold with your code, on orders that are paid and not refunded. You must say you earn commission when you share it. You can&apos;t use
            your own code.
          </p>
          {!aff ? (
            <div style={{ marginTop: 28 }}>
              <p className="muted" style={{ marginBottom: 8 }}>
                Already an affiliate? Get your dashboard link again:
              </p>
              <AffiliateResend />
            </div>
          ) : null}
        </div>

        <div>
          {!aff ? (
            typeof sp.t === "string" ? (
              <div className="form-card">
                <div className="form-title">
                  <h3>Link not recognised</h3>
                </div>
                <p className="muted">Check the link in your email, or ask for it again on the left.</p>
              </div>
            ) : (
              <AffiliateJoin />
            )
          ) : (
            <div className="form-card aff-card">
              <div className="form-title">
                <h3>{sp.new ? "You're in" : "Your dashboard"}</h3>
                <span>{aff.name}</span>
              </div>
              {sp.new ? (
                <p className="muted" style={{ marginTop: 0 }}>
                  <b>Bookmark this page.</b> It&apos;s your private dashboard; we&apos;ve also emailed the link to {aff.payout_email}.
                </p>
              ) : null}
              <p className="muted" style={{ margin: "0 0 4px" }}>
                Your code
              </p>
              <p className="aff-code gold-text">{aff.code}</p>
              <p className="muted" style={{ margin: "0 0 8px" }}>
                Share link (fills your code in)
              </p>
              <CopyText text={shareUrl(aff)} />
              <p className="field-hint" style={{ marginTop: 8 }}>
                When you share it, say you earn commission, e.g. &ldquo;#ad: use my code {aff.code} for 10% off&rdquo;. It&apos;s an ACCC
                requirement. <a href="/terms#affiliates">Affiliate terms</a>
              </p>
              <div className="aff-stats">
                <div>
                  <b>{stats!.orders}</b>
                  <span>paid orders</span>
                </div>
                <div>
                  <b>{stats!.items}</b>
                  <span>items</span>
                </div>
                <div>
                  <b>{money(stats!.earned / 100)}</b>
                  <span>earned</span>
                </div>
                <div>
                  <b className="gold-text">{money(stats!.owed / 100)}</b>
                  <span>to be paid</span>
                </div>
              </div>
              <p className="fine">
                Paid so far: {money(stats!.paid / 100)}. Commission goes to {aff.payout_email} by PayPal each month. Keep this page&apos;s link
                private.
              </p>
            </div>
          )}
        </div>
      </div>
    </section>
  );
}
