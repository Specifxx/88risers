import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { MomentsForm } from "@/components/MomentsForm";
import { MOMENTS_FULL_SET, MOMENT_ITEMS } from "@/lib/momentsConfig";

export const metadata: Metadata = {
  title: "88 Moments",
  description: `Your biggest arm wrestling moment, shot at an 88 Risers event or Nationals and turned into sumi-e ink artwork: framed prints, metal prints, scrolls, shirts and crystal. Up to $${MOMENTS_FULL_SET} for the full set. For registered Risers.`,
  openGraph: { images: ["/moments/opa-artwork.webp"] },
};

/** Finished pieces, newest last. */
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
            <p className="eyebrow">Event camera · sumi-e ink artwork</p>
            <h1 className="display">
              88 <span className="gold-text">Moments.</span>
            </h1>
            <p className="lede">
              We shoot Risers&apos; matches at 88 Risers tournaments, supermatches and meets, <b>and at Nationals</b>. Pick
              your moment (the pin, the comeback, the roar) and we turn it into a <b>sumi-e ink artwork</b>, made for your
              wall.
            </p>
            <p className="mo-risers">
              <b>For registered Risers only.</b> Not a Riser yet? <Link href="/join">Register free →</Link>
            </p>
            <div className="mo-price-tag">
              <span>Pieces from</span>
              <b>$30</b>
              <span>· the full set</span>
              <b>${MOMENTS_FULL_SET}</b>
            </div>
            <a href="#order" className="btn btn-primary">
              Order your moment ↓
            </a>
          </div>
          <a className="mo-art" href="/moments/opa-artwork.webp" target="_blank" rel="noreferrer" title="Open full size">
            <Image src="/moments/opa-artwork.webp" alt="Sumi-e ink artwork of two arm wrestlers locked up at an 88 Risers table, with OPA! in brush script" fill sizes="(max-width: 860px) 100vw, 520px" priority />
          </a>
        </div>

        <div className="mo-series">
          <div className="mo-series-head">
            <h2>
              The Moment <span className="gold-text">Series</span>
            </h2>
            <p className="open-sub">Every piece signed and numbered</p>
          </div>
          {SERIES.map((m) => (
            <article key={m.no} className="mo-moment">
              <a className="mo-moment-art" href={m.art} target="_blank" rel="noreferrer" title="Open full size">
                <Image src={m.art} alt={`${m.title} sumi-e artwork`} fill sizes="(max-width: 860px) 100vw, 380px" />
              </a>
              <div className="mo-moment-body">
                <p className="mo-moment-no">
                  Moment {m.no} / 88
                </p>
                <h3>{m.title}</h3>
                <a className="mo-moment-set" href={m.set} target="_blank" rel="noreferrer" title="Open full size">
                  <Image src={m.set} alt={`The ${m.title} collection: framed print, hanging scroll, metal print, printed shirt and crystal cube`} fill sizes="(max-width: 860px) 100vw, 760px" />
                </a>
              </div>
            </article>
          ))}
        </div>

        <div className="join-grid mo-grid">
          <div>
            <div className="open-block">
              <h2>The pieces</h2>
              <p className="open-sub">Pick any, or take the full set</p>
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
                    <b>The full set</b>
                    <small>All five pieces of the same moment</small>
                  </span>
                  <i>${MOMENTS_FULL_SET}</i>
                </li>
              </ul>
              <p className="open-note">Every order includes the high-res digital artwork. Postage is extra; pick up at a meet is free.</p>
            </div>

            <div className="open-block">
              <h2>How it works</h2>
              <ol className="mo-steps">
                <li>
                  <b>Pull as a Riser.</b> At 88 events or at Nationals, we film and photograph your matches.
                </li>
                <li>
                  <b>Order your moment.</b> Tell us the match; nothing to pay yet.
                </li>
                <li>
                  <b>Approve the artwork.</b> We pick the best frame, ink it in our sumi-e style with the red seal and your words,
                  and send you a preview.
                </li>
                <li>
                  <b>Pay, then it&apos;s made.</b> Printed pieces are ready in about 2–3 weeks, signed and numbered.
                </li>
              </ol>
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
