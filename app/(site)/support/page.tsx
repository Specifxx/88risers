import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { SITE } from "@/lib/site";
import { donateHref } from "@/lib/support";

export const metadata: Metadata = {
  title: "Support the club",
  description: "Donate to 88 Risers club funds or become a club sponsor. Every dollar goes back into tables, chalk, prizes and free meets in Rhodes.",
};

const AMOUNTS = [5, 10, 20, 50];

const FUNDS = [
  ["Tables & pads", "Competition-grade tables, elbow pads and grips that last."],
  ["Free meets", "Keeping monthly meets in Rhodes free, with drinks and snacks on us."],
  ["Prizes", "Chalk season prizes, giveaway prizes and the Top Riser katana."],
  ["Comps & travel", "Entry fees and gear for Risers representing the club."],
] as const;

const PERKS = [
  "Your logo and link on this page and in the footer of every page",
  "“Presented by” credit on 88RisersTV, a supermatch, or a Chalk season prize",
  "Shout-outs on @88risers_ and at meets",
  "Your brand on club shirts and printed cards (bigger packages)",
  "Products as prizes welcome: in-kind sponsorship counts",
];

export default function SupportPage() {
  const sponsorMail = `mailto:${SITE.email}?subject=${encodeURIComponent("Sponsoring 88 Risers")}`;
  return (
    <>
      <section className="page-hero">
        <div className="wrap">
          <p className="crumbs">
            <Link href="/">Home</Link> / Support the club
          </p>
          <h1 className="display">
            Back the <span className="gold-text">club.</span>
          </h1>
          <p className="lede">
            88 Risers is run by volunteers and meets are free. Donations and sponsors pay for the tables, the chalk and
            the prizes, and keep it that way.
          </p>
        </div>
      </section>

      <section className="section" style={{ paddingTop: 32 }}>
        <div className="wrap support">
          <div className="support-card" id="donate">
            <p className="eyebrow">Donate</p>
            <h2 className="display">
              Chip in to <span className="gold-text">club funds.</span>
            </h2>
            <p className="muted">
              Any amount helps. Pay with PayPal or a debit/credit card, once or monthly. No PayPal account needed.
            </p>
            <div className="support-amounts">
              {AMOUNTS.map((a) => (
                <a key={a} className="support-amt" href={donateHref("funds", a)} target="_blank" rel="noreferrer">
                  ${a}
                </a>
              ))}
            </div>
            <a className="btn btn-primary" href={donateHref("funds")} target="_blank" rel="noreferrer">
              Donate any amount with PayPal
            </a>
            <p className="support-alt">Secure checkout by PayPal. You&apos;ll get a receipt by email.</p>
            <ul className="support-funds">
              {FUNDS.map(([t, d]) => (
                <li key={t}>
                  <b>{t}</b>
                  <span>{d}</span>
                </li>
              ))}
            </ul>
          </div>

          <div className="support-card support-sponsor" id="sponsor">
            <p className="eyebrow">Sponsor</p>
            <h2 className="display">
              Put your name <span className="gold-text">on the table.</span>
            </h2>
            <p className="muted">
              Gyms, physios, supplement shops, cafés and bars: get in front of a growing, local, very strong crowd. Packages
              to suit any budget.
            </p>
            <ul className="support-perks">
              {PERKS.map((p) => (
                <li key={p}>{p}</li>
              ))}
            </ul>
            <div className="btn-row">
              <a className="btn btn-primary" href={sponsorMail}>
                Become a sponsor
              </a>
              <a className="btn btn-ghost" href={SITE.instagramUrl} target="_blank" rel="noreferrer">
                DM @{SITE.instagramHandle}
              </a>
            </div>
            <p className="support-alt">
              Agreed on a package? Pay it here:{" "}
              <a href={donateHref("sponsor")} target="_blank" rel="noreferrer">
                sponsorship payment via PayPal ↗
              </a>
            </p>
            <div className="support-current">
              <small>Proudly sponsored by</small>
              <Image src="/sponsors/supp-station.webp" alt="Supp Station" width={393} height={156} />
              <span>Supp Station · presenting sponsor of 88RisersTV</span>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
