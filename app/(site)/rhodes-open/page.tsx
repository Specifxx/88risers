import type { Metadata } from "next";
import Link from "next/link";
import { OpenEntryForm } from "@/components/OpenEntryForm";
import { OPEN, bracketCounts, classLabel, openEntries } from "@/lib/rhodesOpen";
import { SITE } from "@/lib/site";

/** Served from cache; regenerated at most once a minute, or right after someone enters. */
export const revalidate = 60;

export const metadata: Metadata = {
  title: "Rhodes Open 2027",
  description:
    "Rhodes Open 2027 · Sunday 4 April 2027 at Rhodes Amphitheatre. Right and left arm, five weight classes each, ten champion cards and $500 cash in the Champion of Champions finals. Entries open (preliminary draft).",
};

const TBC = <span className="open-tbc">TBC</span>;

export default async function RhodesOpenPage() {
  const counts = bracketCounts(await openEntries());
  const total = counts.reduce((n, c) => n + c.right + c.left, 0);
  return (
    <>
      <section className="page-hero open-page" style={{ paddingBottom: 90 }}>
        <div className="wrap">
          <div className="open-draft" role="note">
            <b>Preliminary draft</b>
            <span>
              Times, weigh-ins, format and prices aren&apos;t final yet and may change. Entering now holds your spot: there&apos;s
              nothing to pay, and we&apos;ll text you before anything is locked in.
            </span>
          </div>

          <div className="join-grid">
            <div>
              <p className="crumbs">
                <Link href="/events">Events</Link> / Rhodes Open
              </p>
              <h1 className="display">
                Rhodes <span className="gold-text">Open</span> 2027
              </h1>
              <p className="open-when">
                {OPEN.date} · {OPEN.venue} · Start {TBC}
              </p>
              <p className="lede">
                Right arm. Left arm. Five weight classes each. <b>Ten champion cards.</b> Every puller leaves with a coin.
              </p>
              <div className="open-cash">
                <b>$500 cash</b>
                <span>up for grabs in the Champion of Champions</span>
              </div>
              <a href="#enter" className="btn btn-primary open-jump">
                Enter now ↓
              </a>

              <div className="open-block">
                <h2>Weight classes</h2>
                <p className="open-sub">Right and left arm</p>
                <div className="open-classes">
                  {OPEN.classes.map((c) => (
                    <span key={c}>{classLabel(c)}</span>
                  ))}
                </div>
                <p className="open-note">
                  Weigh-ins: {TBC} · Allowance: {TBC}
                </p>
              </div>

              <div className="open-block">
                <h2>Prizes</h2>
                <p className="open-sub">Every division, both arms</p>
                <ul className="open-prizes">
                  <li>
                    <i>🥇</i>
                    <span>
                      <b>Custom cased 88 Risers Champion Card</b> + supplement pack
                    </span>
                  </li>
                  <li>
                    <i>🥈</i>
                    <span>
                      <b>Rhodes Open shirt</b> + supplement pack
                    </span>
                  </li>
                  <li>
                    <i>🥉</i>
                    <span>
                      <b>Supplement pack</b>
                    </span>
                  </li>
                </ul>
              </div>

              <div className="open-block open-coc">
                <h2>Champion of Champions</h2>
                <p className="open-sub">Open weight · $500 cash</p>
                <p>
                  Every class winner goes again. The five right-arm champions pull off for the <b>Right-arm Absolute</b>, and
                  the five left-arm champions for the <b>Left-arm Absolute</b>, no weight limits.
                </p>
                <div className="open-coc-prizes">
                  <div>
                    <span>Right-arm Absolute</span>
                    <b>$250</b>
                  </div>
                  <div>
                    <span>Left-arm Absolute</span>
                    <b>$250</b>
                  </div>
                </div>
                <p className="open-note">Cash paid by bank transfer after the event. Format for the finals: {TBC}</p>
              </div>

              <div className="open-block">
                <h2>Entry</h2>
                <table className="open-prices">
                  <thead>
                    <tr>
                      <th />
                      <th>One arm</th>
                      <th>Both arms</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr>
                      <th>
                        Early bird <small>until {TBC}</small>
                      </th>
                      <td>$35</td>
                      <td>$50</td>
                    </tr>
                    <tr>
                      <th>Standard</th>
                      <td>$40</td>
                      <td>$55</td>
                    </tr>
                  </tbody>
                </table>
                <p className="open-note">
                  Every entrant receives the limited <b>Rhodes Open 2027 collectible coin</b>, plus a{" "}
                  <Link href="/pullers">Riser ID</Link> if you don&apos;t have one yet. No payment is taken on this page.
                </p>
              </div>

              <div className="open-block">
                <h2>Format</h2>
                <ul className="open-list">
                  <li>Right-arm brackets run first, then left arm, so you can enter both.</li>
                  <li>Single or double elimination: {TBC}</li>
                  <li>
                    88 Risers rules · Waiver signed at check-in · <Link href="/conduct">Code of Conduct</Link>
                  </li>
                  <li>Classes with fewer than 3 entrants merge into the next class up.</li>
                  <li>Champion of Champions finals run after each arm&apos;s brackets: class winners only, open weight.</li>
                </ul>
              </div>

              <div className="open-block">
                <h2>Entered so far</h2>
                <p className="open-sub">{total ? `${total} bracket ${total === 1 ? "spot" : "spots"} taken` : "Be the first in"}</p>
                <table className="open-prices open-counts">
                  <thead>
                    <tr>
                      <th>Class</th>
                      <th>Right</th>
                      <th>Left</th>
                    </tr>
                  </thead>
                  <tbody>
                    {counts.map((c) => (
                      <tr key={c.cls}>
                        <th>{classLabel(c.cls)}</th>
                        <td>{c.right}</td>
                        <td>{c.left}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              <p className="open-note">
                Questions?{" "}
                <a href={SITE.instagramUrl} target="_blank" rel="noreferrer">
                  DM @{SITE.instagramHandle}
                </a>
              </p>
            </div>
            <div className="open-form-col">
              <OpenEntryForm />
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
