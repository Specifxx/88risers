import Image from "next/image";
import Link from "next/link";
import { CardFace } from "@/components/CardFace";
import { Countdown } from "@/components/Countdown";
import { HeroLion } from "@/components/HeroLion";
import { Arrow, ArrowUpRight, Bolt, Calendar, Instagram, Pin, Search, Shield, Trophy, Users } from "@/components/Icons";
import { JoinForm } from "@/components/JoinForm";
import { Leaderboard } from "@/components/Leaderboard";
import { PullerSlab } from "@/components/PullerSlab";
import { Slab } from "@/components/Slab";
import { KIND_LABEL, upcomingCalendar } from "@/lib/calendar";
import { getClubStats, getLeaderboard, listPullers } from "@/lib/data";
import { fmtDay, fmtDayNum, fmtMonth, fmtTime, fmtWeekday } from "@/lib/schedule";
import { SITE, formatId } from "@/lib/site";

/** Served from cache; regenerated at most once a minute, or immediately after admin edits. */
export const revalidate = 60;

const TICKER = [
  "First Sunday · Every month",
  "Rhodes NSW",
  "Free energy drinks & snacks",
  "Win your own champion card",
  "AAF associated",
  "All levels welcome",
  "Looking for the 88th Riser",
];

const FAQ = [
  [
    "I've never arm wrestled. Can I come?",
    "Absolutely — most people at their first meet haven't. Tell us you're new and someone will walk you through grip, setup and safe technique before you pull anyone.",
  ],
  [
    "What should I bring?",
    "Comfortable clothes and water. Our sponsors keep the energy drinks and snacks coming, so you won't go hungry.",
  ],
  [
    "Do I have to compete?",
    "No. Plenty of people come for the social side and to learn. Tournaments are there when you want them — and that's where Riser IDs, Elo ratings and champion cards come in.",
  ],
  [
    "How do I get a Riser ID?",
    "Register on this site, then pull at an 88 Risers event. We'll add you to the Riser Database with the next permanent member number — it's yours for good.",
  ],
  [
    "What's the champion card?",
    "Win an 88 Risers tournament and you take home a custom-designed trading card of yourself, graded-style in an acrylic case. One of a kind, like the founders' cards on this page.",
  ],
  [
    "Who are you affiliated with?",
    `We're associated with the ${SITE.federation}.`,
  ],
] as const;

export default async function Home() {
  const [stats, leaders, founders, calendar] = await Promise.all([
    getClubStats(),
    getLeaderboard(5),
    listPullers().then((ps) => ps.filter((p) => p.is_founder)),
    upcomingCalendar(3),
  ]);
  const taken = new Set(stats.taken);
  const next = calendar.find((c) => !c.cancelled) ?? calendar[0];
  const nextTraining = calendar.find((c) => c.kind === "training" && !c.cancelled);
  const pct = Math.min(100, (stats.members / SITE.goal) * 100);
  // Homepage card row: Harry, Phillip, Bhavya, Erick. Kelvin (#005) shows in the founders grid instead.
  const showcase = founders.filter((f) => f.card_url && f.title && f.id !== 5).slice(0, 4);

  return (
    <>
      {/* ───────── HERO ───────── */}
      <section className="hero">
        <div className="hero-bg" />
        <div className="wrap hero-grid">
          <div>
            <div className="hero-stamp">WANTED</div>
            <h1 className="display">
              <span className="line">The 88<span className="ord">TH</span></span>
              <span className="line gold-text">Riser.</span>
            </h1>
            <p className="lede">
              <strong>88 Risers is an arm wrestling club in Rhodes, Sydney.</strong> Eight founders, one table, and a mission
              to reach 88 pullers. Every Riser gets a permanent ID, a public match record — and a shot at their own cased
              champion card.
            </p>
            <div className="hero-ctas">
              <Link href="#join" className="btn btn-primary">
                Claim your Riser ID <Arrow />
              </Link>
              <a href={SITE.instagramUrl} className="btn btn-ghost" target="_blank" rel="noreferrer">
                <Instagram /> @{SITE.instagramHandle}
              </a>
            </div>
            <div className="hero-stats">
              <div>
                <b>
                  {String(stats.members).padStart(2, "0")}
                  <span className="gold">/88</span>
                </b>
                <span>Risers</span>
              </div>
              <div>
                <b>{nextTraining ? `${fmtDayNum(nextTraining.start)} ${fmtMonth(nextTraining.start)}` : "1st Sun"}</b>
                <span>Next meet</span>
              </div>
              <div>
                <b>Free</b>
                <span>Drinks & snacks</span>
              </div>
            </div>
          </div>
          <div className="hero-card">
            <HeroLion />
            <div className="halo" />
            <Slab label={{ name: "Your name here", sub: "Future champion", grade: String(stats.next_id).padStart(3, "0"), gradeLabel: "NEXT ID" }} tilt={16}>
              <CardFace name="This could be you" id={stats.next_id} mystery priority />
            </Slab>
            <p className="hero-card-caption">
              Next available Riser ID · <b>{formatId(stats.next_id)}</b>
            </p>
          </div>
        </div>
      </section>

      <div className="marquee" aria-hidden>
        <div className="marquee-track">
          {[...TICKER, ...TICKER].map((t, i) => (
            <span key={i}>{t}</span>
          ))}
        </div>
      </div>
      <div className="marquee red" aria-hidden>
        <div className="marquee-track">
          {[...TICKER, ...TICKER].reverse().map((t, i) => (
            <span key={i}>{t}</span>
          ))}
        </div>
      </div>

      {/* ───────── THE 88 ───────── */}
      <section className="section eighty-eight" id="the-88">
        <div className="ink ink-lion-line ink-88" aria-hidden />
        <div className="wrap">
          <div className="section-head" data-reveal>
            <div>
              <p className="eyebrow">The mission</p>
              <h2 className="display">
                88 seats.
                <br />
                <span className="gold-text">One is yours.</span>
              </h2>
            </div>
            <p className="lede">
              Every member gets a <strong>permanent Riser ID</strong>. Founders hold #001–#008. The next number goes to
              whoever shows up next — and somewhere out there is <strong>Riser #088</strong>. Then we keep going.
            </p>
          </div>

          <div data-reveal>
            <div className="progress">
              <b>{stats.members}</b>
              <div className="progress-bar" role="progressbar" aria-valuenow={stats.members} aria-valuemin={0} aria-valuemax={88} aria-label="Members toward 88">
                <i style={{ width: `${pct}%` }} />
              </div>
              <span>of 88</span>
            </div>
            <div className="grid88">
              {Array.from({ length: 88 }, (_, i) => i + 1).map((n) => {
                const p = founders.find((f) => f.id === n);
                if (taken.has(n))
                  return (
                    <Link key={n} href={`/pullers/${n}`} className="cell taken" title={p?.name ?? `Riser ${formatId(n)}`}>
                      {String(n).padStart(2, "0")}
                      {p ? <small>{p.name.split(" ")[0]}</small> : null}
                    </Link>
                  );
                if (n === stats.next_id)
                  return (
                    <Link key={n} href="#join" className="cell next" title="Claim this number">
                      {String(n).padStart(2, "0")}
                      <small>YOU?</small>
                    </Link>
                  );
                return (
                  <span key={n} className={`cell ${n === 88 ? "final" : ""}`} aria-hidden>
                    {String(n).padStart(2, "0")}
                  </span>
                );
              })}
            </div>
          </div>

          <div className="id-explainer" data-reveal>
            <div>
              <span className="k">01 · REGISTER</span>
              <b>Sign up here</b>
              <p>Name, phone, photo. Thirty seconds. We text you the details for the next meet.</p>
            </div>
            <div>
              <span className="k">02 · PULL</span>
              <b>Show up & compete</b>
              <p>Come to an 88 Risers event. Once you&apos;ve pulled, we add you to the database with your number.</p>
            </div>
            <div>
              <span className="k">03 · RISE</span>
              <b>Build your record</b>
              <p>Every tournament match is logged to your ID: results, Elo, rating and match video.</p>
            </div>
          </div>
        </div>
      </section>

      {/* ───────── THE CLUB ───────── */}
      <section className="section" id="club" style={{ paddingTop: 0 }}>
        <div className="ink ink-circle ink-club" aria-hidden />
        <div className="wrap">
          <div className="section-head" data-reveal>
            <div>
              <p className="eyebrow">The club</p>
              <h2 className="display">
                Not a gym.
                <br />A <span className="red">meet.</span>
              </h2>
            </div>
            <p className="lede">
              Our events are social first. Pull a few rounds, learn some technique, meet people who want to see you get
              stronger. Strength in the grip, <strong>respect at the table</strong>.
            </p>
          </div>
          <div className="tiles">
            <div className="tile wide photo-tile" data-reveal>
              <Image src="/founders/bhavya.jpg" alt="" fill sizes="(max-width: 1000px) 100vw, 620px" />
              <div className="tile-inner">
                <h3>First Sunday. Every month.</h3>
                <p>
                  Table time at {SITE.training.venue}, {SITE.training.suburb} — {SITE.training.timeLabel}. Turn up, pull,
                  hang out.
                </p>
              </div>
            </div>
            <div className="tile red-tile" data-reveal>
              <Bolt className="tile-icon" />
              <h3>Fuelled for free</h3>
              <p>Our sponsors keep the energy drinks and snacks flowing at every meet.</p>
            </div>
            <div className="tile" data-reveal>
              <span className="tile-big">8</span>
              <Users className="tile-icon" />
              <h3>Eight founders</h3>
              <p>Started by eight mates who love the sport. Now we want 80 more.</p>
            </div>
            <div className="tile" data-reveal>
              <Shield className="tile-icon" />
              <h3>AAF associated</h3>
              <p>Associated with the Australian Arm Wrestling Federation (AAF).</p>
            </div>
            <div className="tile gold-tile" data-reveal>
              <Trophy className="tile-icon" />
              <h3>All levels</h3>
              <p>Never pulled before? Perfect. We&apos;ll teach you the setup before you lock up with anyone.</p>
            </div>
            <div className="tile wide" data-reveal>
              <span className="tile-big">ELO</span>
              <Calendar className="tile-icon" />
              <h3>Every match counts</h3>
              <p>
                Tournament results feed a live Elo rating on your public Riser profile, with match video. Watch yourself
                climb.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* ───────── CHAMPION CARDS ───────── */}
      <section className="section champions" id="cards">
        <div className="ink ink-cloud ink-cards" aria-hidden />
        <div className="wrap champions-grid">
          <div data-reveal>
            <p className="eyebrow">The prize</p>
            <h2 className="display">
              Win the table.
              <br />
              <span className="gold-text">Get carded.</span>
            </h2>
            <p className="lede" style={{ marginTop: 24 }}>
              Win an 88 Risers tournament and you walk away with a <strong>custom champion card of yourself</strong> —
              designed from your photos and sealed in an acrylic case like a graded collectible.
            </p>
            <ol className="steps">
              <li>
                <b>01</b>
                <div>
                  <strong>Enter a tournament</strong>
                  <span>Divisions by weight class and arm. Every match is logged to your Riser ID.</span>
                </div>
              </li>
              <li>
                <b>02</b>
                <div>
                  <strong>Take the title</strong>
                  <span>Title matches are flagged on your Riser profile forever.</span>
                </div>
              </li>
              <li>
                <b>03</b>
                <div>
                  <strong>Collect your slab</strong>
                  <span>A one-off card with your name, division and title — cased and yours to keep.</span>
                </div>
              </li>
            </ol>
          </div>
          <div className="fan" data-reveal>
            {showcase.map((p) => (
              <PullerSlab key={p.id} p={p} />
            ))}
          </div>
        </div>
      </section>

      {/* ───────── TABLE TIME ───────── */}
      <section className="section" id="table-time">
        <div className="ink ink-cloud ink-table" aria-hidden />
        <div className="wrap">
          <div className="section-head" data-reveal>
            <div>
              <p className="eyebrow">Table time</p>
              <h2 className="display">
                Pull up a <span className="gold-text">chair.</span>
              </h2>
            </div>
            <p className="lede">
              We meet on the <strong>first Sunday of every month</strong> at {SITE.training.venue}. Tournaments and
              socials get announced here and on Instagram — register to get them by text.
            </p>
          </div>
          <div className="tabletime">
            {next ? (
              <div className="next-session" data-reveal>
                <span className={`pill ${next.cancelled ? "dim" : "red"}`}>
                  {next.cancelled ? "Cancelled" : `Next up · ${KIND_LABEL[next.kind] ?? "Event"}`}
                </span>
                <div className="date-block">
                  <span className="day">{fmtDayNum(next.start)}</span>
                  <span className="mon">
                    {fmtMonth(next.start)}
                    <small>
                      {fmtWeekday(next.start)} · {fmtTime(next.start)}
                      {next.end ? `–${fmtTime(next.end)}` : ""}
                    </small>
                  </span>
                </div>
                <Countdown to={next.start.toISOString()} />
                <dl className="facts">
                  <div>
                    <dt>What</dt>
                    <dd>{next.title}</dd>
                  </div>
                  <div>
                    <dt>Where</dt>
                    <dd>
                      {next.venue}, {SITE.training.suburb}
                    </dd>
                  </div>
                  <div>
                    <dt>Fuel</dt>
                    <dd>Free energy drinks & snacks</dd>
                  </div>
                  <div>
                    <dt>Bring</dt>
                    <dd>Comfy clothes, water, a mate</dd>
                  </div>
                </dl>
                <div className="btn-row">
                  <a className="btn btn-gold btn-sm" href={SITE.training.mapsUrl} target="_blank" rel="noreferrer">
                    <Pin /> Directions
                  </a>
                  <a className="btn btn-sm" href={`/api/calendar?start=${next.start.toISOString()}`}>
                    <Calendar /> Add to calendar
                  </a>
                </div>
              </div>
            ) : null}
            <div className="event-list" data-reveal>
              {calendar.slice(next ? 1 : 0, 5).map((c) => {
                const body = (
                  <>
                    <div className="event-date">
                      <b>{fmtDayNum(c.start)}</b>
                      <span>{fmtMonth(c.start)}</span>
                    </div>
                    <div>
                      <h3>{c.title}</h3>
                      <p>
                        {fmtDay(c.start)} · {fmtTime(c.start)} · {c.venue}
                      </p>
                    </div>
                    <span className={`pill ${c.kind === "tournament" ? "red" : c.cancelled ? "dim" : ""}`}>
                      {c.cancelled ? "Cancelled" : KIND_LABEL[c.kind] ?? "Event"}
                    </span>
                  </>
                );
                return c.href ? (
                  <Link key={c.key} href={c.href} className="event-row">
                    {body}
                  </Link>
                ) : (
                  <div key={c.key} className="event-row">
                    {body}
                  </div>
                );
              })}
              <Link href="/events" className="link-arrow" style={{ marginTop: 10 }}>
                All events & results <span>→</span>
              </Link>
            </div>
          </div>
        </div>
      </section>

      {/* ───────── DATABASE ───────── */}
      <section className="section" id="database" style={{ background: "var(--ink-1)", borderBlock: "1px solid var(--line)" }}>
        <div className="wrap db-band">
          <div data-reveal>
            <p className="eyebrow">Riser Database</p>
            <h2 className="display" style={{ fontSize: "clamp(56px, 7.4vw, 110px)" }}>
              Your record
              <br />
              <span className="gold-text">lives here.</span>
            </h2>
            <p className="lede" style={{ marginTop: 22 }}>
              Every 88 Risers tournament match is logged against a puller&apos;s permanent ID: wins, losses, Elo, rating
              tier and the video of the pull. Look yourself up — or scout your next opponent.
            </p>
            <form className="search" action="/pullers" role="search">
              <input name="q" type="search" placeholder="Name or Riser ID, e.g. 008" aria-label="Search pullers" />
              <button className="btn btn-primary btn-sm" type="submit">
                <Search /> Search
              </button>
            </form>
          </div>
          <div data-reveal>
            <Leaderboard rows={leaders} />
            <div style={{ marginTop: 16, display: "flex", justifyContent: "flex-end" }}>
              <Link href="/pullers" className="link-arrow">
                Open the database <span>→</span>
              </Link>
            </div>
          </div>
        </div>
      </section>

      {/* ───────── FOUNDERS ───────── */}
      <section className="section" id="founders">
        <div className="ink ink-lion ink-founders" aria-hidden />
        <div className="wrap">
          <div className="section-head" data-reveal>
            <div>
              <p className="eyebrow">Riser IDs #001 – #008</p>
              <h2 className="display">
                The <span className="gold-text">founding</span> eight.
              </h2>
            </div>
            <p className="lede">
              Eight friends, one shared obsession. They built 88 Risers so anyone in Sydney could find a table, a crew
              and a reason to keep showing up.
            </p>
          </div>
          <div className="founders">
            {founders.map((p) => (
              <div key={p.id} data-reveal>
                <PullerSlab p={p} />
              </div>
            ))}
          </div>
        </div>
      </section>

      <div className="cloud-rule" aria-hidden>
        <span className="cloud" />
      </div>

      {/* ───────── JOIN ───────── */}
      <section className="section join" id="join">
        <div className="ink ink-lion-line ink-join" aria-hidden />
        <div className="wrap join-grid">
          <div data-reveal>
            <p className="eyebrow">Register</p>
            <h2 className="display">
              Be the
              <br />
              <span className="gold-text">next riser.</span>
            </h2>
            <p className="lede" style={{ marginTop: 22 }}>
              No account, no fees. Leave your name, number and a photo and we&apos;ll text you before every meet and
              tournament.
            </p>
            <ol className="join-steps">
              <li>
                <strong>Register below</strong>
                Takes about thirty seconds.
              </li>
              <li>
                <strong>Get the text</strong>
                Dates, times and what to bring — straight to your phone.
              </li>
              <li>
                <strong>Pull & get your ID</strong>
                Compete at an event and you&apos;re in the Riser Database for good.
              </li>
            </ol>
          </div>
          <div data-reveal>
            <JoinForm nextId={stats.next_id} />
          </div>
        </div>
      </section>

      {/* ───────── INSTAGRAM ───────── */}
      <a className="ig-band" href={SITE.instagramUrl} target="_blank" rel="noreferrer">
        <div className="wrap">
          <p className="eyebrow">Follow the crew</p>
          <div className="ig-handle">
            <Instagram />@{SITE.instagramHandle}
            <ArrowUpRight />
          </div>
          <p className="lede" style={{ marginTop: 20 }}>
            Match clips, event drops, results and the occasional upset. Follow so you never miss a meet.
          </p>
        </div>
      </a>

      {/* ───────── FAQ ───────── */}
      <section className="section" id="faq">
        <div className="ink ink-cloud ink-faq" aria-hidden />
        <div className="wrap faq">
          <div data-reveal>
            <p className="eyebrow">Before you pull</p>
            <h2 className="display">
              Good
              <br />
              <span className="gold-text">questions.</span>
            </h2>
            <p className="lede" style={{ marginTop: 22 }}>
              Anything else? Email <a href={`mailto:${SITE.email}`}>{SITE.email}</a> or DM us on Instagram.
            </p>
          </div>
          <div data-reveal>
            {FAQ.map(([q, a], i) => (
              <details key={q} open={i === 0}>
                <summary>{q}</summary>
                <p>{a}</p>
              </details>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
