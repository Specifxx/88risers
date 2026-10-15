import type { Metadata } from "next";
import Link from "next/link";
import { notFound, permanentRedirect } from "next/navigation";
import { Avatar } from "@/components/Avatar";
import { EloChart, type EloPoint } from "@/components/EloChart";
import { Instagram } from "@/components/Icons";
import { PullerSlab } from "@/components/PullerSlab";
import { VideoToggle } from "@/components/VideoToggle";
import { getPuller, getPullerMatches, type MatchView } from "@/lib/data";
import { PROVISIONAL_MATCHES, START_ELO, tierFor } from "@/lib/elo";
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
    description: `${p.name} — 88 Risers ${formatId(p.id)}. Elo ${p.elo}, record ${p.wins}–${p.losses}.`,
    openGraph: p.card_url || p.photo_url ? { images: [p.card_url || p.photo_url!] } : undefined,
  };
}

function summary(id: number, matches: MatchView[]) {
  const chrono = [...matches].reverse();
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
  const points: EloPoint[] = chrono.length
    ? [
        { elo: START_ELO, label: "Starting rating", date: day(chrono[0].played_on) },
        ...chrono.map((m) => {
          const won = m.winner_id === id;
          return {
            elo: (won ? m.winner_elo_after : m.loser_elo_after) ?? START_ELO,
            label: `${won ? "Beat" : "Lost to"} ${won ? m.loser_name : m.winner_name}`,
            date: day(m.played_on),
          };
        }),
      ]
    : [];
  return { streak, streakType, right: arm("right"), left: arm("left"), points };
}

export default async function PullerPage({ params }: PageProps<"/pullers/[id]">) {
  const raw = (await params).id;
  const id = parseId(raw);
  if (!id) notFound();
  if (raw !== String(id)) permanentRedirect(`/pullers/${id}`);
  const p = await getPuller(id);
  if (!p) notFound();
  const matches = await getPullerMatches(id);
  const s = summary(id, matches);
  const total = p.wins + p.losses;
  const tier = tierFor(p.elo);
  const provisional = total < PROVISIONAL_MATCHES;

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
              <span className="pill">{tier.name}</span>
              {p.title ? <span className="pill">{p.title}</span> : null}
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
                <span>Elo</span>
                <b>{p.elo}</b>
                <small>{provisional ? "Provisional" : `Peak ${p.peak_elo}`}</small>
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

            {s.points.length > 1 ? (
              <div className="panel">
                <h2 className="panel-title">
                  Rating history <small>ELO</small>
                </h2>
                <EloChart points={s.points} />
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
                  const before = won ? m.winner_elo_before : m.loser_elo_before;
                  const after = won ? m.winner_elo_after : m.loser_elo_after;
                  const delta = before != null && after != null ? after - before : null;
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
                      <div className="match-elo">
                        {delta !== null ? (
                          <span className={delta >= 0 ? "up" : "down"}>
                            {delta >= 0 ? "+" : ""}
                            {delta}
                          </span>
                        ) : null}
                        <small>{after ?? ""} ELO</small>
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
