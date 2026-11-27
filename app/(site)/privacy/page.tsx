import type { Metadata } from "next";
import Link from "next/link";
import { SITE } from "@/lib/site";

export const metadata: Metadata = {
  title: "Privacy",
  description: "What personal information 88 Risers collects, why, who can see it, and how to get it changed or deleted.",
};

const UPDATED = "28 November 2026";

const SECTIONS: { id: string; title: string; points: React.ReactNode[] }[] = [
  {
    id: "collect",
    title: "What we collect",
    points: [
      "Registering as a Riser: your name, mobile, Instagram (optional), a photo, and the Riser number you ask for.",
      "A website account: your handle, display name and a securely hashed password (we can't see your password).",
      "Shop orders and 88 Moments bookings: your name, email, mobile, delivery address, what you ordered, and your PayPal transaction ID. Card details go to PayPal only.",
      "Affiliates: your name, code, email, mobile, how you're paid (PayPal email, or bank account name, BSB and account number), and the sales made with your code.",
      "Events: entries (arm, weight class, Riser ID), check-ins, results and match videos.",
      "Training log: the notes you write in your log.",
      "Basic, anonymous visit statistics (pages viewed, device type) through Vercel Web Analytics, which doesn't use advertising cookies.",
    ],
  },
  {
    id: "use",
    title: "Why we use it",
    points: [
      "To run the club: text you about meets, add you to the Riser Database, record results and Chalk, and run events.",
      "To fill orders and bookings: process payments, send receipts, post or hand over your order, and contact you about it.",
      "To pay affiliates their commission. Bank details are only used for that and only the club organisers can see them.",
      "We only send marketing texts or emails if you've agreed to them, and you can opt out any time (reply STOP to texts). Order receipts and messages about your booking aren't marketing.",
      "We never sell your information.",
    ],
  },
  {
    id: "public",
    title: "What's public",
    points: [
      "If you compete as a Riser, your name, photo or card, Riser number, results, Chalk and match videos appear on your public profile and on 88RisersTV.",
      "Your mobile, email, address and registration photo are never public.",
      "Your training log is private to you and the club organisers (it's part of our training study; organisers can read and export logs, and may publish anonymised findings).",
      "Tell us if you'd rather not be shown publicly and we'll hide your profile or a video.",
    ],
  },
  {
    id: "who",
    title: "Who can see it",
    points: [
      "The club organisers, through the private admin area.",
      "Services that run the site for us: Vercel (website hosting, file storage and analytics), Neon (database), PayPal (payments) and Google (our 88risers@gmail.com email). Some of these store data outside Australia.",
      "Embedded videos from YouTube, Instagram and TikTok may set their own cookies when you play them.",
    ],
  },
  {
    id: "keep",
    title: "Keeping it safe",
    points: [
      "The site runs over HTTPS, passwords are hashed, private photos are only shown inside the admin area, and order pages need a private link.",
      "We keep order records as long as we need them for tax (generally five years), and other information while you're involved with the club. Ask us any time to delete what we don't need to keep.",
    ],
  },
  {
    id: "rights",
    title: "Your choices",
    points: [
      <>
        Ask us to see, correct or delete your information, or stop texts or emails, by emailing <a href={`mailto:${SITE.email}`}>{SITE.email}</a> or
        DMing <a href={SITE.instagramUrl}>@{SITE.instagramHandle}</a>.
      </>,
      "If you're under 18, ask a parent or guardian before giving us your details or competing.",
      <>
        Not happy with how we've handled your information? Tell us first and we&apos;ll fix it. You can also contact the Office of the Australian
        Information Commissioner (oaic.gov.au).
      </>,
    ],
  },
];

export default function PrivacyPage() {
  return (
    <>
      <section className="page-hero">
        <div className="wrap">
          <p className="crumbs">
            <Link href="/">Home</Link> / Privacy
          </p>
          <h1 className="display">
            Your <span className="gold-text">privacy.</span>
          </h1>
          <p className="lede">What we collect, why, who can see it, and how to get it changed or deleted. Updated {UPDATED}.</p>
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
            <h2>Questions?</h2>
            <p>
              Email <a href={`mailto:${SITE.email}`}>{SITE.email}</a>. See also our <Link href="/terms">Terms &amp; Refunds</Link> and{" "}
              <Link href="/conduct">Code of Conduct</Link>.
            </p>
          </div>
        </div>
      </section>
    </>
  );
}
