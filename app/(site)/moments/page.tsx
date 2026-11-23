import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { MomentsForm } from "@/components/MomentsForm";
import { MOMENTS_FULL_SET, MOMENTS_ITEMS_SUM, MOMENT_ITEMS } from "@/lib/momentsConfig";

const FROM = Math.min(...MOMENT_ITEMS.map((i) => i.price));

export const metadata: Metadata = {
  title: "88 Moments",
  description: `Book the 88 Risers camera before your next comp (88 events or Nationals). We follow you at the table, then turn your biggest moment into sumi-e ink artwork: framed prints, metal prints, scrolls, shirts and crystal. The full Risers Moment Package is $${MOMENTS_FULL_SET}. For registered Risers.`,
  openGraph: { images: ["/moments/opa-artwork.webp"] },
};

/** Example artwork (not real orders), newest last. */
const SERIES = [
  { no: "01", title: "OPA!", art: "/moments/opa-artwork.webp", set: "/moments/opa-collection.webp" },
  { no: "02", title: "WATCH ME.", art: "/moments/watch-me-artwork.webp", set: "/moments/watch-me-collection.webp" },
];

export default function MomentsPage() {
  return (
    <section className="page-hero mo-page" style={{ paddingBottom: 90 }}>
      <div className="wrap">
        <p className="crumbs">
          <Link href="/">Home</Link> / 88 Moments
        </p>
        <div className="mo-hero">
          <div>
            <p className="eyebrow">Book the camera · sumi-e ink artwork</p>
            <h1 className="display">
              88 <span className="gold-text">Moments.</span>
            </h1>
            <p className="lede">
              Book us <b>before your next comp</b>, at an 88 Risers event <b>or at Nationals</b>, and our camera follows{" "}
              <b>you</b>: every pull, every roar. Then we turn your biggest moment into a <b>sumi-e ink artwork</b> made for
              your wall.
            </p>
            <p className="mo-risers">
              <b>For registered Risers only.</b> Not a Riser yet? <Link href="/join">Register free →</Link>
            </p>
            <div className="mo-price-tag">
              <span>Pieces from</span>
              <b>${FROM}</b>
              <span>· full package</span>
              <b>${MOMENTS_FULL_SET}</b>
            </div>
            <a href="#order" className="btn btn-primary">
              Book your moment ↓
            </a>
          </div>
          <a className="mo-art" href="/moments/opa-artwork.webp" target="_blank" rel="noreferrer" title="Open full size">
            <Image src="/moments/opa-artwork.webp" alt="Sumi-e ink artwork of two arm wrestlers locked up at an 88 Risers table, with OPA! in brush script" fill sizes="(max-width: 860px) 100vw, 520px" priority />
          </a>
        </div>

        <div className="mo-series">
          <div className="mo-series-head">
            <h2>
              Example <span className="gold-text">moments</span>
            </h2>
            <p className="open-sub">What a Risers Moment Package can look like</p>
          </div>
          {SERIES.map((m) => (
            <article key={m.no} className="mo-moment">
              <a className="mo-moment-art" href={m.art} target="_blank" rel="noreferrer" title="Open full size">
                <Image src={m.art} alt={`${m.title} sumi-e artwork (example)`} fill sizes="(max-width: 860px) 100vw, 380px" />
              </a>
              <div className="mo-moment-body">
                <p className="mo-moment-no">Example {m.no}</p>
                <h3>{m.title}</h3>
                <a className="mo-moment-set" href={m.set} target="_blank" rel="noreferrer" title="Open full size">
                  <Image src={m.set} alt={`The ${m.title} example: framed print, hanging scroll, metal print, printed shirt and crystal cube`} fill sizes="(max-width: 860px) 100vw, 760px" />
                </a>
              </div>
            </article>
          ))}
        </div>

        <div className="join-grid mo-grid">
          <div>
            <div className="open-block">
              <h2>How it works</h2>
              <ol className="mo-steps">
                <li>
                  <b>Book before the comp.</b> Tell us the event, your division and arm. Nothing to pay yet.
                </li>
                <li>
                  <b>We shoot you.</b> On the day, the camera is on you: warm-up, walk-out, every match, the result.
                </li>
                <li>
                  <b>Your moment becomes art.</b> We pick your best frame and ink it in our sumi-e style, with the red seal and
                  your words, then send you a preview.
                </li>
                <li>
                  <b>Approve, pay, it&apos;s made.</b> Printed pieces are ready in about 2–3 weeks.
                </li>
              </ol>
            </div>

            <div className="open-block">
              <h2>The pieces</h2>
              <p className="open-sub">Pick any, or take the full package</p>
              <ul className="mo-list">
                {MOMENT_ITEMS.map((i) => (
                  <li key={i.id}>
                    <span>
                      <b>{i.name}</b>
                      <small>{i.blurb}</small>
                    </span>
                    <i>${i.price}</i>
                  </li>
                ))}
                <li className="mo-set">
                  <span>
                    <b>The full Risers Moment Package</b>
                    <small>
                      All five pieces of your moment · save ${MOMENTS_ITEMS_SUM - MOMENTS_FULL_SET}
                    </small>
                  </span>
                  <i>${MOMENTS_FULL_SET}</i>
                </li>
              </ul>
              <p className="open-note">Every booking includes the high-res digital artwork. Postage is extra; pick up at a meet is free.</p>
            </div>
          </div>
          <div className="open-form-col">
            <MomentsForm />
          </div>
        </div>
      </div>
    </section>
  );
}
