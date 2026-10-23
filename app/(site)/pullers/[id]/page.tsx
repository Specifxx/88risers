import type { Metadata } from "next";
import Link from "next/link";
import { notFound, permanentRedirect } from "next/navigation";
import { Avatar } from "@/components/Avatar";
import { Instagram } from "@/components/Icons";
import { PullerSlab } from "@/components/PullerSlab";
import { VideoToggle } from "@/components/VideoToggle";
import { getPuller, getPullerMatches, type MatchView } from "@/lib/data";
import { chalkOf, currentSeason } from "@/lib/chalk";
import { medal, placeLabel, podiumChalk, resultsFor } from "@/lib/results";
import { fmtShortDate } from "@/lib/schedule";
import { formatId } from "@/lib/site";

/** Served from cache; regenerated at most once a minute, or immediately after admin edits. */
export const revalidate = 60;

// Pages are generated on first visit, then cached.
export function generateStaticParams() {
  return [];
}

function parseId(raw: string) {
  const m = /^#?0*(\d{1,6})$/.exec(decodeURIComponent(raw));
  return m ? Number(m[1]) : null;
}

const day = (iso: string) => fmtShortDate(new Date(`${iso}T12:00:00+10:00`));

export async function generateMetadata({ params }: PageProps<"/pullers/[id]">): Promise<Metadata> {
  const id = parseId((await params).id);
  const p = id ? await getPuller(id) : null;
  if (!p) return { title: "Riser not found" };
  return {
    title: `${p.name} · ${formatId(p.id)}`,
    description: `${p.name} — 88 Risers ${formatId(p.id)}. Record ${p.wins}–${p.losses}.`,
    openGraph: p.card_url || p.photo_url ? { images: [p.card_url || p.photo_url!] } : undefined,
  };
}

function summary(id: number, matches: MatchView[]) {
  let streak = 0;
  let streakType: "W" | "L" | null = null;
  for (const m of matches) {
    const t = m.winner_id === id ? "W" : "L";
    if (streakType === null) streakType = t;
    if (t !== streakType) break;
    streak++;
  }
  const arm = (a: string) => {
    const ms = matches.filter((m) => m.arm === a);
    return { w: ms.filter((m) => m.winner_id === id).length, l: ms.filter((m) => m.loser_id === id).length };
  };
  return { streak, streakType, right: arm("right"), left: arm("left") };
}

export default async function PullerPage({ params }: PageProps<"/pullers/[id]">) {
  const raw = (await params).id;
  const id = parseId(raw);
  if (!id) notFound();
  if (raw !== String(id)) permanentRedirect(`/pullers/${id}`);
  const p = await getPuller(id);
  if (!p) notFound();
  const [matches, results] = await Promise.all([getPullerMatches(id), resultsFor(id)]);
  const podiums = results.filter((r) => r.place <= 3);
  const s = summary(id, matches);
  const total = p.wins + p.losses;
  const season = currentSeason();
  const chalk = p.account_id ? await chalkOf(p.account_id, season) : null;

  return (
    <section className="page-hero" style={{ paddingBottom: 100 }}>
      <div className="wrap">
        <p className="crumbs">
          <Link href="/">Home</Link> / <Link href="/pullers">Riser Database</Link> / {formatId(p.id)}
        </p>
        <div className="profile">
          <div className="profile-card">
            <PullerSlab p={p} link={false} priority />
          </div>
          <div>
            <p className="profile-id gold-text">
              <small>PERMANENT RISER ID</small>
              {formatId(p.id)}
            </p>
            <h1 className="display">{p.name}</h1>
            {p.nickname ? <p className="lede" style={{ marginTop: 8 }}>“{p.nickname}”</p> : null}
            <div className="profile-tags">
              {p.is_founder ? <span className="pill red">Founding member</span> : null}
              {p.account_handle ? (
                <Link className="pill gold-pill" href={`/members/${p.account_handle}`} style={{ textDecoration: "none" }}>
                  @{p.account_handle} · member profile →
                </Link>
              ) : null}
              {p.title ? <span className="pill">{p.title}</span> : null}
              {podiums.slice(0, 3).map((r) => (
                <span key={r.id} className="pill gold-pill">
                  {medal(r.place)} {placeLabel(r.place)} · {r.event}
                  {r.division ? ` ${r.division}` : ""}
                </span>
              ))}
              {p.weight_class ? <span className="pill dim">{p.weight_class}</span> : null}
              {p.dominant_arm ? <span className="pill dim">{p.dominant_arm} arm</span> : null}
              {p.instagram ? (
                <a className="pill dim" href={`https://www.instagram.com/${p.instagram}/`} target="_blank" rel="noreferrer" style={{ textDecoration: "none" }}>
                  <Instagram width={12} height={12} /> @{p.instagram}
                </a>
              ) : null}
            </div>
            {p.bio ? (
              <div className="prose" style={{ marginTop: 22 }}>
                <p>{p.bio}</p>
              </div>
            ) : null}

            <div className="stat-grid">
              <div className="stat hl">
                <span>Chalk · {season}</span>
                <b>{chalk ?? "—"}</b>
                <small>
                  {p.account_handle ? (
                    <Link href={`/members/${p.account_handle}`}>@{p.account_handle} →</Link>
                  ) : (
                    "Season points"
                  )}
                </small>
              </div>
              <div className="stat">
                <span>Record</span>
                <b>
                  {p.wins}–{p.losses}
                </b>
                <small>{total ? `${Math.round((p.wins / total) * 100)}% win rate` : "No matches yet"}</small>
              </div>
              <div className="stat">
                <span>By arm</span>
                <b style={{ fontSize: "clamp(24px, 2.6vw, 32px)", display: "block" }}>
                  <i className="muted" style={{ fontSize: "0.6em", fontStyle: "normal" }}>R </i>
                  {s.right.w}–{s.right.l}
                </b>
                <b style={{ fontSize: "clamp(24px, 2.6vw, 32px)", display: "block", marginTop: 4 }}>
                  <i className="muted" style={{ fontSize: "0.6em", fontStyle: "normal" }}>L </i>
                  {s.left.w}–{s.left.l}
                </b>
              </div>
              <div className="stat">
                <span>{p.titles ? "Titles" : "Streak"}</span>
                <b>{p.titles ? p.titles : s.streak ? `${s.streakType}${s.streak}` : "—"}</b>
                <small>{p.titles ? "Title matches won" : "Current run"}</small>
              </div>
            </div>

            {results.length ? (
              <div className="panel">
                <h2 className="panel-title">
                  Tournament record <small>{podiums.length} {podiums.length === 1 ? "PODIUM" : "PODIUMS"}</small>
                </h2>
                <ul className="results-list">
                  {results.map((r) => (
                    <li key={r.id} className={r.place <= 3 ? `place-${r.place}` : undefined}>
                      <span className="res-medal" aria-hidden>
                        {medal(r.place)}
                      </span>
                      <span className="res-main">
                        <b>
                          {placeLabel(r.place)} · {r.event}
                        </b>
                        <small>
                          {[r.division, r.played_on ? day(r.played_on) : String(r.season), r.notes].filter(Boolean).join(" · ")}
                        </small>
                      </span>
                      {podiumChalk(r.place) ? <span className="res-chalk">+{podiumChalk(r.place)} Chalk</span> : null}
                    </li>
                  ))}
                </ul>
              </div>
            ) : null}

            <div className="panel">
              <h2 className="panel-title">
                Match record <small>{total} MATCHES</small>
              </h2>
              {matches.length === 0 ? (
                <div className="empty" style={{ padding: "20px 0" }}>
                  No recorded matches yet. Results from 88 Risers tournaments appear here — with video.
                </div>
              ) : (
                matches.map((m) => {
                  const won = m.winner_id === p.id;
                  const oppId = won ? m.loser_id : m.winner_id;
                  const oppName = won ? m.loser_name : m.winner_name;
                  const oppPhoto = won ? m.loser_photo : m.winner_photo;
                  return (
                    <div className="match" key={m.id}>
                      <div className={`result ${won ? "w" : "l"}`}>{won ? "W" : "L"}</div>
                      <div className="match-main">
                        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                          <Avatar src={oppPhoto} name={oppName} size={28} />
                          <b>
                            vs <Link href={`/pullers/${oppId}`}>{oppName}</Link>{" "}
                            <span className="muted tech" style={{ fontSize: 12 }}>
                              {formatId(oppId)}
                            </span>
                          </b>
                        </div>
                        <div className="match-meta">
                          <span>{day(m.played_on)}</span>
                          <span>{m.arm} arm</span>
                          {m.round ? <span>{m.round}</span> : null}
                          {m.weight_class ? <span>{m.weight_class}</span> : null}
                          {m.score ? <span>Score {m.score}</span> : null}
                          {m.is_title_match ? <span className="gold">★ Title match</span> : null}
                          {m.event_slug ? (
                            <Link href={`/events/${m.event_slug}`} className="gold" style={{ textDecoration: "none" }}>
                              {m.event_title}
                            </Link>
                          ) : null}
                        </div>
                        {m.video_url ? <VideoToggle url={m.video_url} /> : null}
                      </div>
                    </div>
                  );
                })
              )}
            </div>
            <p className="fine">
              Riser since {day(p.joined_on)}. Spotted a mistake in your record? DM us on Instagram.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}
