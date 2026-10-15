import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Avatar } from "@/components/Avatar";
import { isAdminKey } from "@/lib/admin";
import { getClubStats, listEvents, listPullers, listRecentMatches, listRegistrations, type ClubEvent, type MatchView, type Puller } from "@/lib/data";
import { prettyPhone } from "@/lib/phone";
import { fmtShortDate, toSydneyInput } from "@/lib/schedule";
import { SITE, formatId } from "@/lib/site";
import {
  deleteEvent,
  deleteMatch,
  deletePuller,
  deleteRegistration,
  promoteRegistration,
  saveEvent,
  saveMatch,
  savePuller,
  saveRegistrationNote,
  setRegistrationStatus,
} from "./actions";
import { ConfirmButton, CopyButton, ImageInput } from "./ui";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "HQ",
  robots: { index: false, follow: false, nocache: true },
  referrer: "no-referrer",
};

const TABS = [
  ["registrations", "Registrations"],
  ["pullers", "Pullers"],
  ["matches", "Matches"],
  ["events", "Events"],
] as const;
type Tab = (typeof TABS)[number][0];

const fmtWhen = (d: Date) =>
  new Intl.DateTimeFormat("en-AU", { timeZone: SITE.timeZone, day: "numeric", month: "short", hour: "numeric", minute: "2-digit" }).format(d);

export default async function AdminPage({ params, searchParams }: PageProps<"/admin/[key]">) {
  const { key } = await params;
  if (!isAdminKey(decodeURIComponent(key))) notFound();
  const sp = await searchParams;
  const tab: Tab = (TABS.find(([t]) => t === sp.tab)?.[0] ?? "registrations") as Tab;
  const msg = typeof sp.msg === "string" ? sp.msg : null;
  const err = typeof sp.err === "string" ? sp.err : null;
  const filter = typeof sp.status === "string" ? sp.status : "active";
  const k = decodeURIComponent(key);
  const base = `/admin/${encodeURIComponent(k)}`;

  const [stats, regs, pullers, matches, events] = await Promise.all([
    getClubStats(),
    listRegistrations(),
    listPullers({ includeHidden: true }),
    listRecentMatches(200),
    listEvents("all"),
  ]);
  const newRegs = regs.filter((r) => r.status === "new").length;

  return (
    <div className="admin">
      <header className="admin-top">
        <div className="wrap">
          <Link href="/" className="brand" target="_blank">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/crest.jpg" alt="" width={38} height={38} />
            <span>
              <b>88 Risers HQ</b>
              <small>Admin · private link</small>
            </span>
          </Link>
          <div className="admin-kpis">
            <div>
              <b>{regs.length}</b>
              <span>Registered</span>
            </div>
            <div>
              <b className={newRegs ? "red" : ""}>{newRegs}</b>
              <span>New</span>
            </div>
            <div>
              <b>
                {stats.members}
                <small>/88</small>
              </b>
              <span>Risers</span>
            </div>
            <div>
              <b>{stats.matches}</b>
              <span>Matches</span>
            </div>
          </div>
        </div>
        <nav className="wrap admin-tabs">
          {TABS.map(([t, label]) => (
            <Link key={t} href={`${base}?tab=${t}`} aria-current={t === tab ? "page" : undefined}>
              {label}
              {t === "registrations" && newRegs ? <i>{newRegs}</i> : null}
            </Link>
          ))}
        </nav>
      </header>

      <main className="wrap admin-main">
        {msg ? <div className="flash ok">{msg}</div> : null}
        {err ? <div className="flash bad">{err}</div> : null}

        {tab === "registrations" ? <Registrations regs={regs} k={k} base={base} filter={filter} nextId={stats.next_id} /> : null}
        {tab === "pullers" ? <Pullers pullers={pullers} k={k} nextId={stats.next_id} /> : null}
        {tab === "matches" ? <Matches matches={matches} pullers={pullers} events={events} k={k} /> : null}
        {tab === "events" ? <Events events={events} k={k} /> : null}

        <p className="fine" style={{ marginTop: 60 }}>
          Anyone with this link can manage the club, so share it only with organisers. To change the link, set a new
          ADMIN_KEY in Vercel and redeploy.
        </p>
      </main>
    </div>
  );
}

/* ─────────── Registrations ─────────── */

function Registrations({
  regs,
  k,
  base,
  filter,
  nextId,
}: {
  regs: Awaited<ReturnType<typeof listRegistrations>>;
  k: string;
  base: string;
  filter: string;
  nextId: number;
}) {
  const shown = regs.filter((r) => (filter === "all" ? true : filter === "active" ? r.status !== "archived" : r.status === filter));
  const textable = regs.filter((r) => r.sms_consent && r.status !== "archived");
  return (
    <>
      <div className="admin-head">
        <div>
          <h1>Registrations</h1>
          <p className="muted">People who signed up on the site. Text them event details, then add whoever pulls to the database.</p>
        </div>
        <div className="btn-row">
          <CopyButton text={textable.map((r) => r.phone).join(", ")} label={`Copy ${textable.length} numbers`} />
          <a className="btn btn-sm btn-gold" href={`/api/admin/export?k=${encodeURIComponent(k)}`}>
            Export CSV
          </a>
        </div>
      </div>
      <div className="chips">
        {[
          ["active", "Active"],
          ["new", "New"],
          ["contacted", "Contacted"],
          ["puller", "In database"],
          ["archived", "Archived"],
          ["all", "All"],
        ].map(([s, l]) => (
          <Link key={s} href={`${base}?tab=registrations&status=${s}`} aria-current={filter === s ? "page" : undefined}>
            {l}
          </Link>
        ))}
      </div>
      {shown.length === 0 ? (
        <div className="panel empty">
          <b>Nobody here yet</b>
          Share {SITE.url.replace(/^https?:\/\//, "")}/join in your Instagram bio to start collecting sign-ups.
        </div>
      ) : (
        <div className="reg-list">
          {shown.map((r) => (
            <div className="reg" key={r.id}>
              <a
                className="reg-photo"
                href={r.photo_id ? `/api/photos/${r.photo_id}?k=${encodeURIComponent(k)}` : undefined}
                target="_blank"
                rel="noreferrer"
              >
                {r.photo_id ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={`/api/photos/${r.photo_id}?k=${encodeURIComponent(k)}`} alt={r.name} loading="lazy" />
                ) : (
                  <span>No photo</span>
                )}
              </a>
              <div className="reg-body">
                <div className="reg-name">
                  <b>{r.name}</b>
                  <span className={`pill ${r.status === "new" ? "red" : r.status === "puller" ? "" : "dim"}`}>
                    {r.status === "puller" ? `Riser ${formatId(r.puller_id!)}` : r.status}
                  </span>
                </div>
                <div className="reg-meta">
                  <a href={`tel:${r.phone}`}>{prettyPhone(r.phone)}</a>
                  <a href={`sms:${r.phone}`}>Text</a>
                  {r.instagram ? (
                    <a href={`https://www.instagram.com/${r.instagram}/`} target="_blank" rel="noreferrer">
                      @{r.instagram}
                    </a>
                  ) : null}
                  <span>Registered {fmtWhen(new Date(r.created_at))}</span>
                </div>
                <form action={saveRegistrationNote} className="reg-note">
                  <input type="hidden" name="key" value={k} />
                  <input type="hidden" name="registration_id" value={r.id} />
                  <input name="notes" className="input" defaultValue={r.notes ?? ""} placeholder="Private note (e.g. 85kg, lefty, came to Nov meet)" />
                  <button className="btn btn-sm btn-ghost">Save</button>
                </form>
              </div>
              <div className="reg-actions">
                {r.status === "puller" ? (
                  <Link className="btn btn-sm" href={`/pullers/${r.puller_id}`} target="_blank">
                    View profile ↗
                  </Link>
                ) : (
                  <form action={promoteRegistration} className="promote">
                    <input type="hidden" name="key" value={k} />
                    <input type="hidden" name="registration_id" value={r.id} />
                    <label>
                      <span>ID #</span>
                      <input name="riser_id" type="number" min={1} defaultValue={nextId} className="input" />
                    </label>
                    <button className="btn btn-sm btn-primary">Add to database</button>
                  </form>
                )}
                <div className="btn-row">
                  {r.status === "new" ? (
                    <form action={setRegistrationStatus}>
                      <input type="hidden" name="key" value={k} />
                      <input type="hidden" name="registration_id" value={r.id} />
                      <input type="hidden" name="status" value="contacted" />
                      <button className="btn btn-sm btn-ghost">Mark texted</button>
                    </form>
                  ) : null}
                  {r.status !== "puller" ? (
                    <form action={setRegistrationStatus}>
                      <input type="hidden" name="key" value={k} />
                      <input type="hidden" name="registration_id" value={r.id} />
                      <input type="hidden" name="status" value={r.status === "archived" ? "new" : "archived"} />
                      <button className="btn btn-sm btn-ghost">{r.status === "archived" ? "Restore" : "Archive"}</button>
                    </form>
                  ) : null}
                  <form action={deleteRegistration}>
                    <input type="hidden" name="key" value={k} />
                    <input type="hidden" name="registration_id" value={r.id} />
                    <ConfirmButton message={`Permanently delete ${r.name}'s registration and photo?`}>Delete</ConfirmButton>
                  </form>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </>
  );
}

/* ─────────── Pullers ─────────── */

function PullerFields({ p, nextId }: { p?: Puller; nextId: number }) {
  return (
    <div className="form-grid">
      <div className="field">
        <label>Riser ID</label>
        <input name="id" type="number" min={1} defaultValue={p?.id ?? nextId} required />
      </div>
      <div className="field span2">
        <label>Name</label>
        <input name="name" type="text" defaultValue={p?.name} required />
      </div>
      <div className="field">
        <label>Nickname</label>
        <input name="nickname" type="text" defaultValue={p?.nickname ?? ""} />
      </div>
      <div className="field span2">
        <label>Title / achievement <em>shown on card</em></label>
        <input name="title" type="text" defaultValue={p?.title ?? ""} placeholder="e.g. 70kg Right Arm Champion" />
      </div>
      <div className="field">
        <label>Weight class</label>
        <input name="weight_class" type="text" defaultValue={p?.weight_class ?? ""} placeholder="e.g. 80kg" />
      </div>
      <div className="field">
        <label>Dominant arm</label>
        <select name="dominant_arm" defaultValue={p?.dominant_arm ?? ""}>
          <option value="">—</option>
          <option value="Right">Right</option>
          <option value="Left">Left</option>
          <option value="Both">Both</option>
        </select>
      </div>
      <div className="field">
        <label>Instagram</label>
        <input name="instagram" type="text" defaultValue={p?.instagram ?? ""} placeholder="@handle" />
      </div>
      <div className="field">
        <label>Member since</label>
        <input name="joined_on" type="date" defaultValue={p?.joined_on ?? ""} />
      </div>
      <div className="field span4">
        <label>Bio</label>
        <textarea name="bio" defaultValue={p?.bio ?? ""} rows={2} />
      </div>
      <div className="field span2">
        <label>Photo <em>headshot</em></label>
        <ImageInput name="photo" max={1000} />
        {p?.photo_url ? (
          <label className="check" style={{ margin: "8px 0 0" }}>
            <input type="checkbox" name="remove_photo" /> <span>Remove current photo</span>
          </label>
        ) : null}
      </div>
      <div className="field span2">
        <label>Champion card image <em>2:3 portrait</em></label>
        <ImageInput name="card" max={1400} />
        {p?.card_url ? (
          <label className="check" style={{ margin: "8px 0 0" }}>
            <input type="checkbox" name="remove_card" /> <span>Remove current card</span>
          </label>
        ) : null}
      </div>
      <label className="check span4" style={{ margin: 0 }}>
        <input type="checkbox" name="hidden" defaultChecked={p?.hidden} />
        <span>Hide from the public site</span>
      </label>
    </div>
  );
}

function Pullers({ pullers, k, nextId }: { pullers: Puller[]; k: string; nextId: number }) {
  return (
    <>
      <div className="admin-head">
        <div>
          <h1>Pullers</h1>
          <p className="muted">The Riser Database. IDs are permanent — only renumber to fix a mistake.</p>
        </div>
      </div>
      <details className="panel admin-new">
        <summary>+ Add a puller manually</summary>
        <form action={savePuller}>
          <input type="hidden" name="key" value={k} />
          <PullerFields nextId={nextId} />
          <button className="btn btn-primary btn-sm">Add puller</button>
        </form>
      </details>
      <div className="admin-rows">
        {pullers.map((p) => (
          <details key={p.id} className="admin-row">
            <summary>
              <span className="rid">{formatId(p.id)}</span>
              <Avatar src={p.photo_url || p.card_url} name={p.name} size={34} />
              <b>{p.name}</b>
              <span className="muted tech">
                ELO {p.elo} · {p.wins}–{p.losses}
              </span>
              {p.is_founder ? <span className="pill">Founder</span> : null}
              {p.hidden ? <span className="pill dim">Hidden</span> : null}
            </summary>
            <form action={savePuller}>
              <input type="hidden" name="key" value={k} />
              <input type="hidden" name="original_id" value={p.id} />
              <PullerFields p={p} nextId={nextId} />
              <div className="btn-row">
                <button className="btn btn-primary btn-sm">Save changes</button>
                <Link className="btn btn-sm btn-ghost" href={`/pullers/${p.id}`} target="_blank">
                  View profile ↗
                </Link>
              </div>
            </form>
            <form action={deletePuller} style={{ marginTop: 12 }}>
              <input type="hidden" name="key" value={k} />
              <input type="hidden" name="id" value={p.id} />
              <ConfirmButton message={`Delete ${p.name} and ALL their matches? This can't be undone.`} className="btn btn-sm btn-ghost danger">
                Delete puller
              </ConfirmButton>
            </form>
          </details>
        ))}
      </div>
    </>
  );
}

/* ─────────── Matches ─────────── */

function MatchFields({ m, pullers, events }: { m?: MatchView; pullers: Puller[]; events: ClubEvent[] }) {
  const options = pullers.map((p) => (
    <option key={p.id} value={p.id}>
      {formatId(p.id)} {p.name}
    </option>
  ));
  return (
    <div className="form-grid">
      <div className="field span2">
        <label>Winner</label>
        <select name="winner_id" defaultValue={m?.winner_id ?? ""} required>
          <option value="" disabled>
            Choose winner…
          </option>
          {options}
        </select>
      </div>
      <div className="field span2">
        <label>Loser</label>
        <select name="loser_id" defaultValue={m?.loser_id ?? ""} required>
          <option value="" disabled>
            Choose loser…
          </option>
          {options}
        </select>
      </div>
      <div className="field span2">
        <label>Event</label>
        <select name="event_id" defaultValue={m?.event_id ?? ""}>
          <option value="">No event / training</option>
          {events.map((e) => (
            <option key={e.id} value={e.id}>
              {fmtShortDate(new Date(e.starts_at))} — {e.title}
            </option>
          ))}
        </select>
      </div>
      <div className="field">
        <label>Date <em>defaults to event</em></label>
        <input name="played_on" type="date" defaultValue={m?.played_on ?? ""} />
      </div>
      <div className="field">
        <label>Arm</label>
        <select name="arm" defaultValue={m?.arm ?? "right"}>
          <option value="right">Right</option>
          <option value="left">Left</option>
        </select>
      </div>
      <div className="field">
        <label>Round</label>
        <input name="round" type="text" defaultValue={m?.round ?? ""} placeholder="Final, Semi, R1…" />
      </div>
      <div className="field">
        <label>Weight class</label>
        <input name="weight_class" type="text" defaultValue={m?.weight_class ?? ""} placeholder="80kg" />
      </div>
      <div className="field">
        <label>Score</label>
        <input name="score" type="text" defaultValue={m?.score ?? ""} placeholder="2–1" />
      </div>
      <div className="field">
        <label>&nbsp;</label>
        <label className="check" style={{ margin: "14px 0 0" }}>
          <input type="checkbox" name="is_title_match" defaultChecked={m?.is_title_match} />
          <span>Title match ★</span>
        </label>
      </div>
      <div className="field span4">
        <label>Video link <em>YouTube, Instagram reel, TikTok, Google Drive or .mp4</em></label>
        <input name="video_url" type="url" defaultValue={m?.video_url ?? ""} placeholder="https://www.instagram.com/reel/…" />
      </div>
      <div className="field span4">
        <label>Notes</label>
        <input name="notes" type="text" defaultValue={m?.notes ?? ""} />
      </div>
    </div>
  );
}

function Matches({ matches, pullers, events, k }: { matches: MatchView[]; pullers: Puller[]; events: ClubEvent[]; k: string }) {
  return (
    <>
      <div className="admin-head">
        <div>
          <h1>Matches</h1>
          <p className="muted">Every match updates both pullers&apos; Elo. Edits and deletions replay all ratings automatically.</p>
        </div>
      </div>
      <div className="panel">
        <h2 className="panel-title">Record a match</h2>
        <form action={saveMatch}>
          <input type="hidden" name="key" value={k} />
          <MatchFields pullers={pullers} events={events} />
          <button className="btn btn-primary btn-sm">Record match</button>
        </form>
      </div>
      <div className="admin-rows">
        {matches.map((m) => (
          <details key={m.id} className="admin-row">
            <summary>
              <span className="rid">{m.played_on}</span>
              <b>
                {m.winner_name} <span className="gold">def.</span> {m.loser_name}
              </b>
              <span className="muted tech">
                {m.arm} · {m.round ?? "—"} {m.video_url ? "· ▶ video" : ""}
              </span>
              {m.is_title_match ? <span className="pill">Title</span> : null}
              {m.event_title ? <span className="pill dim">{m.event_title}</span> : null}
            </summary>
            <form action={saveMatch}>
              <input type="hidden" name="key" value={k} />
              <input type="hidden" name="match_id" value={m.id} />
              <MatchFields m={m} pullers={pullers} events={events} />
              <button className="btn btn-primary btn-sm">Save match</button>
            </form>
            <form action={deleteMatch} style={{ marginTop: 12 }}>
              <input type="hidden" name="key" value={k} />
              <input type="hidden" name="match_id" value={m.id} />
              <ConfirmButton message="Delete this match and recalculate ratings?" className="btn btn-sm btn-ghost danger">
                Delete match
              </ConfirmButton>
            </form>
          </details>
        ))}
        {matches.length === 0 ? <div className="panel empty">No matches recorded yet.</div> : null}
      </div>
    </>
  );
}

/* ─────────── Events ─────────── */

function EventFields({ e }: { e?: ClubEvent }) {
  return (
    <div className="form-grid">
      <div className="field span2">
        <label>Title</label>
        <input name="title" type="text" defaultValue={e?.title} required placeholder="88 Risers Summer Open" />
      </div>
      <div className="field">
        <label>Type</label>
        <select name="kind" defaultValue={e?.kind ?? "tournament"}>
          <option value="tournament">Tournament</option>
          <option value="training">Table time (training)</option>
          <option value="social">Social</option>
          <option value="other">Other</option>
        </select>
      </div>
      <div className="field">
        <label>URL slug <em>optional</em></label>
        <input name="slug" type="text" defaultValue={e?.slug ?? ""} placeholder="auto" />
      </div>
      <div className="field">
        <label>Starts <em>Sydney time</em></label>
        <input name="starts_at" type="datetime-local" defaultValue={e ? toSydneyInput(new Date(e.starts_at)) : ""} required />
      </div>
      <div className="field">
        <label>Ends</label>
        <input name="ends_at" type="datetime-local" defaultValue={e?.ends_at ? toSydneyInput(new Date(e.ends_at)) : ""} />
      </div>
      <div className="field">
        <label>Venue</label>
        <input name="venue" type="text" defaultValue={e?.venue ?? ""} placeholder={SITE.training.venue} />
      </div>
      <div className="field">
        <label>Address</label>
        <input name="address" type="text" defaultValue={e?.address ?? ""} placeholder="for the directions link" />
      </div>
      <div className="field span4">
        <label>Details</label>
        <textarea name="description" defaultValue={e?.description ?? ""} rows={4} placeholder="Divisions, weigh-in time, what to bring, prizes…" />
      </div>
      <label className="check span4" style={{ margin: 0 }}>
        <input type="checkbox" name="cancelled" defaultChecked={e?.cancelled} />
        <span>Cancelled</span>
      </label>
    </div>
  );
}

function Events({ events, k }: { events: ClubEvent[]; k: string }) {
  return (
    <>
      <div className="admin-head">
        <div>
          <h1>Events</h1>
          <p className="muted">
            Monthly table time appears automatically. Add a <b>Table time</b> event on a first Sunday to rename, move or
            cancel that session.
          </p>
        </div>
      </div>
      <div className="panel">
        <h2 className="panel-title">New event</h2>
        <form action={saveEvent}>
          <input type="hidden" name="key" value={k} />
          <EventFields />
          <button className="btn btn-primary btn-sm">Publish event</button>
        </form>
      </div>
      <div className="admin-rows">
        {events.map((e) => (
          <details key={e.id} className="admin-row">
            <summary>
              <span className="rid">{fmtShortDate(new Date(e.starts_at))}</span>
              <b>{e.title}</b>
              <span className="muted tech">
                {e.kind} · {e.match_count} matches
              </span>
              {e.cancelled ? <span className="pill dim">Cancelled</span> : null}
            </summary>
            <form action={saveEvent}>
              <input type="hidden" name="key" value={k} />
              <input type="hidden" name="event_id" value={e.id} />
              <EventFields e={e} />
              <div className="btn-row">
                <button className="btn btn-primary btn-sm">Save event</button>
                <Link className="btn btn-sm btn-ghost" href={`/events/${e.slug}`} target="_blank">
                  View page ↗
                </Link>
              </div>
            </form>
            <form action={deleteEvent} style={{ marginTop: 12 }}>
              <input type="hidden" name="key" value={k} />
              <input type="hidden" name="event_id" value={e.id} />
              <ConfirmButton message={`Delete "${e.title}"? Matches stay in pullers' records.`} className="btn btn-sm btn-ghost danger">
                Delete event
              </ConfirmButton>
            </form>
          </details>
        ))}
        {events.length === 0 ? <div className="panel empty">No custom events yet.</div> : null}
      </div>
    </>
  );
}
