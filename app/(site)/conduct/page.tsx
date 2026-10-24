import type { Metadata } from "next";
import Link from "next/link";
import { SITE } from "@/lib/site";

export const metadata: Metadata = {
  title: "Code of Conduct",
  description: "How we look after each other at 88 Risers: respect, no pressure, safety first, fair play and consent for photos and filming.",
};

const RULES: { title: string; points: string[] }[] = [
  {
    title: "Respect everyone",
    points: [
      "Everyone is welcome at the table, whatever their gender, size, age, background or experience.",
      "No sexist, racist or homophobic comments, no put-downs, and no unwanted touching or attention.",
      "Win well, lose well. Shake hands before and after every pull.",
    ],
  },
  {
    title: "No pressure",
    points: [
      "Nobody has to pull. Watching, chatting and learning are all part of the club.",
      "You choose who you pull. It's always fine to say no, and a no doesn't need a reason.",
      "Don't call people out who don't want to be called out.",
    ],
  },
  {
    title: "Safety first",
    points: [
      "Newcomers learn safe technique before their first pull.",
      "We match people by size and experience. No pulling someone much bigger or more experienced unless you both want to and an organiser is happy with it.",
      "Anyone can stop a pull at any time. If something hurts, stop straight away and tell an organiser.",
      "No pulling if you've been drinking, or while you're carrying an injury.",
    ],
  },
  {
    title: "Fair play",
    points: [
      "Follow the referee's calls and the table rules: elbows on the pads, start on “go”.",
      "No cheating, no deliberately dangerous moves, and no showboating that puts anyone at risk.",
    ],
  },
  {
    title: "Photos & filming",
    points: [
      "Ask before you film or photograph someone pulling, and before you post it.",
      "Tell an organiser if you'd rather not appear in club photos or videos, and we'll keep you out of them.",
      "If you ask us to take down a photo or video of you, we will.",
    ],
  },
  {
    title: "Speak up",
    points: [
      "If anyone makes you uncomfortable, tell an organiser at the meet, or message us privately afterwards. We'll take it seriously and keep it confidential.",
      "Organisers can ask anyone who breaks these rules to leave, and repeat or serious breaches mean you won't be welcome back.",
    ],
  },
];

export default function ConductPage() {
  return (
    <>
      <section className="page-hero">
        <div className="wrap">
          <p className="crumbs">
            <Link href="/">Home</Link> / Code of Conduct
          </p>
          <h1 className="display">
            Code of <span className="gold-text">Conduct.</span>
          </h1>
          <p className="lede">
            88 Risers is a friendly, social club. These are the few rules that keep it that way for everyone, from
            first-timers to competitors.
          </p>
        </div>
      </section>
      <section className="section" style={{ paddingTop: 32 }}>
        <div className="wrap conduct">
          {RULES.map((r, i) => (
            <div key={r.title} className="panel conduct-rule">
              <span className="conduct-num">{String(i + 1).padStart(2, "0")}</span>
              <div>
                <h2>{r.title}</h2>
                <ul>
                  {r.points.map((p) => (
                    <li key={p}>{p}</li>
                  ))}
                </ul>
              </div>
            </div>
          ))}
          <div className="panel conduct-contact">
            <h2>Need to talk to someone?</h2>
            <p>
              Find an organiser at the meet, email <a href={`mailto:${SITE.email}`}>{SITE.email}</a>, or DM{" "}
              <a href={SITE.instagramUrl} target="_blank" rel="noreferrer">
                @{SITE.instagramHandle}
              </a>{" "}
              on Instagram. Messages go straight to the organisers.
            </p>
            <Link className="btn btn-primary" href="/join">
              Register for a meet
            </Link>
          </div>
        </div>
      </section>
    </>
  );
}
