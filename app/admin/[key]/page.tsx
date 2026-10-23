import { fmtOdds, oddsOf, payoutAt } from "@/lib/odds";
import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Avatar } from "@/components/Avatar";
import { isAdminKey } from "@/lib/admin";
import { getClubStats, listEvents, listPullers, listRecentMatches, listReels, listRegistrations, listShopInterest, type ClubEvent, type MatchView, type Puller, type Reel, type ShopInterest } from "@/lib/data";
import { prettyPhone } from "@/lib/phone";
import { fmtShortDate, toSydneyInput } from "@/lib/schedule";
import { mailStatus } from "@/lib/mail";
import { type AdminAccount, type AdminRedemption, STORE, adminAccounts, adminRedemptions, itemById } from "@/lib/coins";
import { type Giveaway, getGiveaway } from "@/lib/giveaway";
import { type CompResult, allResults, placeLabel } from "@/lib/results";
import { CHALK, chalkboard, chalkSettings, currentSeason, listMeets, meetAttendees, sydneyToday } from "@/lib/chalk";
import { type Backer, type Supermatch, listBackers, listSupermatches } from "@/lib/supermatch";
import { PRODUCTS } from "@/lib/shop";
import { SITE, formatId } from "@/lib/site";
import {
  deleteEvent,
  deleteInterest,
  deleteMatch,
  deletePuller,
  deleteReel,
  deleteSupermatch,
  drawGiveaway,
  grantCoins,
  resetAccountPassword,
  saveSupermatch,
  setGiveawayDate,
  openCheckin,
  addResult,
  deleteResult,
  linkPullerAccount,
  setCheckinOpen,
  setMeetTournament,
  addAttendee,
  setPodium,
  adjustChalk,
  saveChalkConfig,
  setRedemptionUsed,
  settleSupermatch,
  deleteRegistration,
  promoteRegistration,
  saveEvent,
  saveMatch,
  savePuller,
  saveReel,
  saveRegistrationNote,
  sendTestEmail,
  setInterestDone,
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
  ["tv", "88RisersTV"],
  ["shop", "Shop"],
  ["coins", "Coins"],
  ["chalk", "Chalk"],
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

  const [stats, regs, pullers, matches, events, reels, interest, sms, accts, redeems, backers, giveaway, results] = await Promise.all([
    getClubStats(),
    listRegistrations(),
    listPullers({ includeHidden: true }),
    listRecentMatches(200),
    listEvents("all"),
    listReels({ includeHidden: true }),
    listShopInterest(),
    listSupermatches(),
    adminAccounts(),
    adminRedemptions(),
    listBackers(),
    getGiveaway(),
    allResults(),
  ]);
  const newRegs = regs.filter((r) => r.status === "new").length;
  const newInterest = interest.filter((r) => !r.done).length;

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
              {t === "shop" && newInterest ? <i>{newInterest}</i> : null}
            </Link>
          ))}
        </nav>
      </header>

      <main className="wrap admin-main">
        {msg ? <div className="flash ok">{msg}</div> : null}
        {err ? <div className="flash bad">{err}</div> : null}

        {tab === "registrations" ? <Registrations regs={regs} k={k} base={base} filter={filter} nextId={stats.next_id} /> : null}
        {tab === "pullers" ? <Pullers pullers={pullers} accts={accts} results={results} k={k} nextId={stats.next_id} /> : null}
        {tab === "matches" ? <Matches matches={matches} pullers={pullers} events={events} k={k} /> : null}
        {tab === "events" ? <Events events={events} k={k} /> : null}
        {tab === "tv" ? <Tv reels={reels} k={k} /> : null}
        {tab === "shop" ? <Shop interest={interest} k={k} /> : null}
        {tab === "chalk" ? <ChalkTab accts={accts} k={k} /> : null}
        {tab === "coins" ? <Coins sms={sms} accts={accts} redeems={redeems} pullers={pullers} backers={backers} giveaway={giveaway} k={k} /> : null}

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
                  {r.requested_id && r.status !== "puller" ? (
                    <span className="pill gold-pill">Wants {formatId(r.requested_id)} · $2 gold coin</span>
                  ) : null}
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
                      <input name="riser_id" type="number" min={1} defaultValue={r.requested_id ?? nextId} className="input" />
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

function Pullers({ pullers, accts, results, k, nextId }: { pullers: Puller[]; accts: AdminAccount[]; results: CompResult[]; k: string; nextId: number }) {
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
                {p.wins}–{p.losses}
                {p.account_handle ? ` · @${p.account_handle}` : " · no member account linked"}
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
            <form action={linkPullerAccount} className="btn-row" style={{ marginTop: 12 }}>
              <input type="hidden" name="key" value={k} />
              <input type="hidden" name="puller_id" value={p.id} />
              <label className="muted" htmlFor={`acct-${p.id}`}>
                Member account <em>(for Chalk from supermatches and podiums)</em>
              </label>
              <select id={`acct-${p.id}`} name="account_id" defaultValue={p.account_id ?? ""}>
                <option value="">Not linked</option>
                {accts.map((a) => (
                  <option key={a.id} value={a.id}>
                    {a.display_name} (@{a.handle})
                  </option>
                ))}
              </select>
              <button className="btn btn-sm">Save link</button>
            </form>
            <div className="admin-results">
              <h4>Competition results</h4>
              {results
                .filter((r) => r.puller_id === p.id)
                .map((r) => (
                  <form key={r.id} action={deleteResult} className="btn-row">
                    <input type="hidden" name="key" value={k} />
                    <input type="hidden" name="result_id" value={r.id} />
                    <span>
                      <b>{placeLabel(r.place)}</b> · {r.event}
                      {r.division ? ` · ${r.division}` : ""} · {r.played_on ?? r.season}
                    </span>
                    <ConfirmButton message={`Remove ${placeLabel(r.place)} at ${r.event}? Its Chalk is removed too.`} className="btn btn-sm btn-ghost danger">
                      Remove
                    </ConfirmButton>
                  </form>
                ))}
              <form action={addResult} className="btn-row">
                <input type="hidden" name="key" value={k} />
                <input type="hidden" name="puller_id" value={p.id} />
                <input name="event" type="text" placeholder="Competition, e.g. NSW State Titles" required />
                <input name="division" type="text" placeholder="Division, e.g. 85kg+ left" style={{ width: 170 }} />
                <select name="place" defaultValue="1">
                  <option value="1">1st</option>
                  <option value="2">2nd</option>
                  <option value="3">3rd</option>
                  <option value="4">4th</option>
                  <option value="5">5th</option>
                  <option value="6">6th+</option>
                </select>
                <input name="played_on" type="date" />
                <button className="btn btn-sm">Add result</button>
              </form>
            </div>
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
          <p className="muted">Matches build each Riser&apos;s win–loss record and title count on their profile.</p>
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
              <ConfirmButton message="Delete this match? It comes off both pullers&apos; records." className="btn btn-sm btn-ghost danger">
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

function ReelFields({ r }: { r?: Reel }) {
  return (
    <div className="form-grid">
      <div className="field span2">
        <label>Reel link</label>
        <input name="url" type="url" defaultValue={r?.url} required placeholder="https://www.instagram.com/reel/…" />
      </div>
      <div className="field span2">
        <label>Title</label>
        <input name="title" type="text" defaultValue={r?.title} required placeholder="Harry vs Erick: the rematch" />
      </div>
      <div className="field span4">
        <label>Caption <em>optional</em></label>
        <textarea name="caption" defaultValue={r?.caption ?? ""} rows={2} placeholder="One or two lines shown under the player" />
      </div>
      <div className="field">
        <label>Posted on</label>
        <input name="posted_on" type="date" defaultValue={r?.posted_on ?? ""} />
      </div>
      <div className="field">
        <label>Order <em>lower plays first</em></label>
        <input name="sort_order" type="number" defaultValue={r?.sort_order ?? 0} />
      </div>
      <label className="check span2" style={{ margin: 0, alignSelf: "end" }}>
        <input type="checkbox" name="hidden" defaultChecked={r?.hidden} />
        <span>Hidden from the site</span>
      </label>
    </div>
  );
}

function Tv({ reels, k }: { reels: Reel[]; k: string }) {
  return (
    <>
      <div className="admin-head">
        <div>
          <h1>88RisersTV</h1>
          <p className="muted">
            Paste reel links from @{SITE.instagramHandle}. The first reel (lowest order number, then newest) is the
            featured broadcast on <Link href="/tv" target="_blank">/tv</Link>.
          </p>
        </div>
      </div>
      <div className="panel">
        <h2 className="panel-title">Add a reel</h2>
        <form action={saveReel}>
          <input type="hidden" name="key" value={k} />
          <ReelFields />
          <button className="btn btn-primary btn-sm">Add to 88RisersTV</button>
        </form>
      </div>
      <div className="admin-rows">
        {reels.map((r, i) => (
          <details key={r.id} className="admin-row">
            <summary>
              <span className="rid">CH {String(i + 1).padStart(2, "0")}</span>
              <b>{r.title}</b>
              <span className="muted tech">{r.posted_on ? fmtShortDate(new Date(r.posted_on)) : "no date"} · order {r.sort_order}</span>
              {r.hidden ? <span className="pill dim">Hidden</span> : null}
            </summary>
            <form action={saveReel}>
              <input type="hidden" name="key" value={k} />
              <input type="hidden" name="reel_id" value={r.id} />
              <ReelFields r={r} />
              <div className="btn-row">
                <button className="btn btn-primary btn-sm">Save reel</button>
                <a className="btn btn-sm btn-ghost" href={r.url} target="_blank" rel="noreferrer">
                  Open on Instagram ↗
                </a>
              </div>
            </form>
            <form action={deleteReel} style={{ marginTop: 12 }}>
              <input type="hidden" name="key" value={k} />
              <input type="hidden" name="reel_id" value={r.id} />
              <ConfirmButton message={`Remove "${r.title}" from 88RisersTV?`} className="btn btn-sm btn-ghost danger">
                Remove reel
              </ConfirmButton>
            </form>
          </details>
        ))}
        {reels.length === 0 ? <div className="panel empty">No reels yet. Paste the first one above.</div> : null}
      </div>
    </>
  );
}

function Shop({ interest, k }: { interest: ShopInterest[]; k: string }) {
  const name = (id: string) => PRODUCTS.find((p) => p.id === id)?.name ?? id;
  const counts = PRODUCTS.map((p) => ({ p, n: interest.filter((r) => r.product === p.id).length }));
  return (
    <>
      <div className="admin-head">
        <div>
          <h1>Shop interest</h1>
          <p className="muted">
            People who registered interest on <Link href="/shop" target="_blank">/shop</Link>. Each one is also emailed
            when email is set up below.
          </p>
        </div>
      </div>
      <MailPanel k={k} />
      <div className="panel interest-counts">
        {counts.map(({ p, n }) => (
          <div key={p.id}>
            <b>{n}</b>
            <span>{p.name}</span>
          </div>
        ))}
      </div>
      <div className="admin-rows">
        {interest.map((r) => (
          <div key={r.id} className={`admin-row interest-row${r.done ? " is-done" : ""}`}>
            <div className="interest-main">
              <b>{r.name}</b>
              <span className="pill">{name(r.product)}</span>
              {r.emailed ? null : <span className="pill dim">Not emailed</span>}
              <span className="muted tech">{fmtWhen(new Date(r.created_at))}</span>
            </div>
            <div className="interest-main">
              <a href={`tel:${r.phone}`}>{prettyPhone(r.phone)}</a>
              <a className="btn btn-sm btn-ghost" href={`sms:${r.phone}`}>Text</a>
              {r.notes ? <span className="muted">“{r.notes}”</span> : null}
            </div>
            <div className="btn-row">
              <form action={setInterestDone}>
                <input type="hidden" name="key" value={k} />
                <input type="hidden" name="interest_id" value={r.id} />
                {r.done ? null : <input type="hidden" name="done" value="on" />}
                <button className="btn btn-sm btn-ghost">{r.done ? "Mark as new" : "Mark contacted"}</button>
              </form>
              <form action={deleteInterest}>
                <input type="hidden" name="key" value={k} />
                <input type="hidden" name="interest_id" value={r.id} />
                <ConfirmButton message={`Remove ${r.name}'s interest in the ${name(r.product)}?`} className="btn btn-sm btn-ghost danger">
                  Remove
                </ConfirmButton>
              </form>
            </div>
          </div>
        ))}
        {interest.length === 0 ? <div className="panel empty">No one has registered interest yet.</div> : null}
      </div>
    </>
  );
}

function MailPanel({ k }: { k: string }) {
  const st = mailStatus();
  const ok = Boolean(st.user && st.hasPassword);
  return (
    <div className="panel mail-panel">
      <h2 className="panel-title">Email notifications</h2>
      <ul>
        <li>
          <span>Send from</span>
          <b className={st.user ? "" : "red"}>{st.user ?? "GMAIL_USER not set"}</b>
        </li>
        <li>
          <span>App password</span>
          <b className={st.hasPassword ? (st.passwordLength === 16 ? "" : "red") : "red"}>
            {st.hasPassword
              ? st.passwordLength === 16
                ? "Set (16 characters)"
                : `Set, but ${st.passwordLength} characters (app passwords are 16)`
              : "GMAIL_APP_PASSWORD not set"}
          </b>
        </li>
        <li>
          <span>Send to</span>
          <b>{st.to}</b>
          <em>change with MAIL_TO</em>
        </li>
      </ul>
      <form action={sendTestEmail}>
        <input type="hidden" name="key" value={k} />
        <button className="btn btn-sm" disabled={!ok}>
          Send test email
        </button>
      </form>
    </div>
  );
}

function Coins({
  sms,
  accts,
  redeems,
  pullers,
  backers,
  giveaway,
  k,
}: {
  sms: Supermatch[];
  accts: AdminAccount[];
  redeems: AdminRedemption[];
  pullers: Puller[];
  backers: Backer[];
  giveaway: Giveaway;
  k: string;
}) {
  const nameOf = (id: number | null) => pullers.find((p) => p.id === id)?.name ?? (id ? `#${id}` : "");
  const SmFields = ({ m }: { m?: Supermatch }) => (
    <div className="form-grid">
      <div className="field span2">
        <label>Title</label>
        <input name="title" type="text" defaultValue={m?.title ?? ""} required placeholder="December Supermatch" />
      </div>
      <div className="field">
        <label>Puller A</label>
        <select name="a_id" defaultValue={m?.a_id ?? ""} required>
          <option value="">Choose…</option>
          {pullers.map((p) => (
            <option key={p.id} value={p.id}>
              {formatId(p.id)} {p.name}
            </option>
          ))}
        </select>
      </div>
      <div className="field">
        <label>Puller B</label>
        <select name="b_id" defaultValue={m?.b_id ?? ""} required>
          <option value="">Choose…</option>
          {pullers.map((p) => (
            <option key={p.id} value={p.id}>
              {formatId(p.id)} {p.name}
            </option>
          ))}
        </select>
      </div>
      <div className="field">
        <label>Voting closes <em>Sydney time</em></label>
        <input name="closes_at" type="datetime-local" defaultValue={m ? toSydneyInput(new Date(m.closes_at)) : ""} required />
      </div>
      <div className="field">
        <label>Arm</label>
        <select name="arm" defaultValue={m?.arm ?? "right"}>
          <option value="right">Right arm</option>
          <option value="left">Left arm</option>
        </select>
      </div>
      <div className="field">
        <label>Coins for a correct pick</label>
        <input name="reward" type="number" min={0} defaultValue={m?.reward ?? 88} />
      </div>
      <div className="field span4">
        <label>Blurb</label>
        <textarea name="blurb" rows={2} defaultValue={m?.blurb ?? ""} />
      </div>
    </div>
  );
  const entries = STORE.filter((i) => i.kind === "entry");
  return (
    <>
      <div className="admin-head">
        <div>
          <h1>Coins &amp; supermatches</h1>
          <p className="muted">
            88Risers coins are free play money. Settle a supermatch after the result to pay everyone who picked right
            (reward + their share of the stake pool at the final odds). Public pages: <Link href="/supermatch" target="_blank">/supermatch</Link>,{" "}
            <Link href="/rewards" target="_blank">/rewards</Link>, <Link href="/play" target="_blank">/play</Link>.
          </p>
        </div>
      </div>

      <div className="panel">
        <h2 className="panel-title">New supermatch</h2>
        <form action={saveSupermatch}>
          <input type="hidden" name="key" value={k} />
          <SmFields />
          <button className="btn btn-primary btn-sm">Create supermatch</button>
        </form>
      </div>
      <div className="admin-rows">
        {sms.map((m) => (
          <details key={m.id} className="admin-row" open={!m.settled_at}>
            <summary>
              <b>
                {m.title} · {m.arm === "left" ? "Left arm" : "Right arm"}
              </b>
              <span className="muted tech">
                {nameOf(m.a_id)} {m.a_votes} · {m.b_votes} {nameOf(m.b_id)} · {m.pot} staked · odds{" "}
                {fmtOdds(oddsOf({ a: m.a_pot, b: m.b_pot }).a)} / {fmtOdds(oddsOf({ a: m.a_pot, b: m.b_pot }).b)}
              </span>
              {m.settled_at ? <span className="pill">Won by {nameOf(m.winner_id)}</span> : <span className="pill">Open</span>}
            </summary>
            <Backers m={m} rows={backers.filter((r) => r.match_id === m.id)} nameOf={nameOf} />
            {!m.settled_at ? (
              <>
                <form action={saveSupermatch}>
                  <input type="hidden" name="key" value={k} />
                  <input type="hidden" name="sm_id" value={m.id} />
                  <SmFields m={m} />
                  <button className="btn btn-sm">Save changes</button>
                </form>
                <form action={settleSupermatch} className="btn-row" style={{ marginTop: 16 }}>
                  <input type="hidden" name="key" value={k} />
                  <input type="hidden" name="sm_id" value={m.id} />
                  <select name="winner_id" required defaultValue="">
                    <option value="">Who won?</option>
                    <option value={m.a_id}>{nameOf(m.a_id)}</option>
                    <option value={m.b_id}>{nameOf(m.b_id)}</option>
                  </select>
                  <ConfirmButton message="Record this result and pay out coins? This can't be undone." className="btn btn-sm btn-primary">
                    Settle &amp; pay out
                  </ConfirmButton>
                </form>
                <form action={deleteSupermatch} style={{ marginTop: 12 }}>
                  <input type="hidden" name="key" value={k} />
                  <input type="hidden" name="sm_id" value={m.id} />
                  <ConfirmButton message={`Delete "${m.title}"? Stakes are refunded.`} className="btn btn-sm btn-ghost danger">
                    Cancel supermatch
                  </ConfirmButton>
                </form>
              </>
            ) : null}
          </details>
        ))}
      </div>

      <div className="panel">
        <h2 className="panel-title">Giveaway draws</h2>
        <form action={setGiveawayDate} className="btn-row" style={{ marginBottom: 16 }}>
          <input type="hidden" name="key" value={k} />
          <label className="muted" htmlFor="draw_at">
            End of Year Giveaway draw <em>(Sydney time, shown as a countdown on the homepage and /rewards)</em>
          </label>
          <input id="draw_at" name="draw_at" type="datetime-local" defaultValue={toSydneyInput(new Date(giveaway.drawAt))} required />
          <button className="btn btn-sm">Save date</button>
        </form>
        {entries.map((i) => {
          const open = redeems.filter((r) => r.item === i.id && !r.fulfilled).length;
          const winners = redeems.filter((r) => r.item === i.id && r.won);
          return (
            <form key={i.id} action={drawGiveaway} className="btn-row">
              <input type="hidden" name="key" value={k} />
              <input type="hidden" name="item" value={i.id} />
              <b>{i.name}</b>
              <span className="muted tech">{open} open entries</span>
              <ConfirmButton message={`Draw a winner from ${open} entries? This closes the round.`} className="btn btn-sm btn-primary">
                Draw winner
              </ConfirmButton>
              {winners.length ? <span className="muted">Past winners: {winners.map((w) => w.display_name).join(", ")}</span> : null}
            </form>
          );
        })}
      </div>

      <div className="panel">
        <h2 className="panel-title">Reward codes</h2>
        {redeems.length ? (
          <div className="admin-rows">
            {redeems.map((r) => (
              <div key={r.id} className={`admin-row interest-row${r.fulfilled ? " is-done" : ""}`}>
                <div className="interest-main">
                  <b>{r.code}</b>
                  <span>{itemById(r.item)?.name ?? r.item}</span>
                  <span className="muted">
                    {r.display_name} (@{r.handle})
                  </span>
                  {r.won ? <span className="pill">Winner</span> : null}
                  <form action={setRedemptionUsed}>
                    <input type="hidden" name="key" value={k} />
                    <input type="hidden" name="redemption_id" value={r.id} />
                    {r.fulfilled ? null : <input type="hidden" name="used" value="on" />}
                    <button className="btn btn-sm btn-ghost">{r.fulfilled ? "Mark unused" : "Mark used"}</button>
                  </form>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <p className="muted">No perks or entries redeemed yet.</p>
        )}
      </div>

      <div className="panel">
        <h2 className="panel-title">Accounts ({accts.length})</h2>
        <div className="admin-rows">
          {accts.map((a) => (
            <details key={a.id} className="admin-row">
              <summary>
                <b>{a.display_name}</b>
                <span className="muted tech">
                  @{a.handle} · {a.coins} coins · {a.picks} {a.picks === 1 ? "pick" : "picks"}{a.best ? ` · best ${a.best}` : ""}
                </span>
              </summary>
              <form action={grantCoins} className="btn-row">
                <input type="hidden" name="key" value={k} />
                <input type="hidden" name="account_id" value={a.id} />
                <input name="amount" type="number" placeholder="+50 or -20" style={{ width: 120 }} />
                <input name="reason" type="text" placeholder="Reason (shown to them)" />
                <button className="btn btn-sm">Adjust coins</button>
              </form>
              <form action={resetAccountPassword} className="btn-row" style={{ marginTop: 10 }}>
                <input type="hidden" name="key" value={k} />
                <input type="hidden" name="account_id" value={a.id} />
                <input name="password" type="text" placeholder="New password (8+ chars)" minLength={8} />
                <button className="btn btn-sm btn-ghost">Reset password</button>
              </form>
            </details>
          ))}
          {accts.length === 0 ? <div className="panel empty">No accounts yet.</div> : null}
        </div>
      </div>
    </>
  );
}

/** Who backed whom on one supermatch, with what each stake pays (or paid). */
function Backers({ m, rows, nameOf }: { m: Supermatch; rows: Backer[]; nameOf: (id: number | null) => string }) {
  if (!rows.length) return <p className="muted" style={{ marginTop: 12 }}>No picks yet.</p>;
  const pools = { a: m.a_pot, b: m.b_pot };
  const odds = oddsOf(pools);
  return (
    <div style={{ overflowX: "auto" }}>
      <table className="sm-backers">
        <thead>
          <tr>
            <th>Member</th>
            <th>Backed</th>
            <th className="num">Stake</th>
            <th className="num">Odds</th>
            <th className="num">Stake × odds</th>
            <th className="num">Bonus</th>
            <th className="num">{m.settled_at ? "Total paid" : "Total if right"}</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => {
            const side = r.pick_id === m.a_id ? "a" : "b";
            const lost = m.winner_id != null && r.pick_id !== m.winner_id;
            const at = r.odds ?? odds[side];
            const ret = payoutAt(r.stake, at);
            return (
              <tr key={r.handle}>
                <td>
                  {r.display_name} <span className="muted">@{r.handle}</span>
                </td>
                <td>
                  {nameOf(r.pick_id)}
                </td>
                <td className="num">{r.stake}</td>
                <td className="num">{r.stake ? fmtOdds(at) : "—"}</td>
                <td className="num">{r.stake && !lost ? ret : "—"}</td>
                <td className="num">{lost ? "—" : m.reward}</td>
                <td className="num">
                  <b>{lost ? 0 : ret + m.reward}</b>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

/** Chalk: meet-day check-in, podiums, settings and the season table. */
async function ChalkTab({ accts, k }: { accts: AdminAccount[]; k: string }) {
  const season = currentSeason();
  const [settings, meets, board] = await Promise.all([chalkSettings(), listMeets(12), chalkboard(season, 10)]);
  const attendees = await Promise.all(meets.map((m) => meetAttendees(m.id)));
  const today = sydneyToday();
  const todayIdx = meets.findIndex((m) => m.day === today);
  const todays = todayIdx >= 0 ? meets[todayIdx] : null;
  const fmtDay = (d: string) =>
    new Intl.DateTimeFormat("en-AU", { weekday: "short", day: "numeric", month: "short", year: "numeric", timeZone: "UTC" }).format(new Date(`${d}T00:00:00Z`));
  const AccountSelect = ({ name, value, options, placeholder }: { name: string; value?: number | null; options: { id: number; display_name: string; handle: string }[]; placeholder: string }) => (
    <select name={name} defaultValue={value ?? ""}>
      <option value="">{placeholder}</option>
      {options.map((a) => (
        <option key={a.id} value={a.id}>
          {a.display_name} (@{a.handle})
        </option>
      ))}
    </select>
  );

  return (
    <>
      <div className="admin-head">
        <div>
          <h1>Chalk · {season} season</h1>
          <p className="muted">
            Members earn Chalk: +{CHALK.checkin} for checking in at a meet, +{CHALK.invite} when someone they invited comes to
            their first meet, {CHALK.podium.join("/")} for a tournament podium, and +{CHALK.supermatch} for pulling in a supermatch (+
            {CHALK.supermatch + CHALK.supermatchWin} for winning it; link the Riser to their account in Pullers). {settings.target} Chalk completes the Lift.
            Public page: <Link href="/chalk" target="_blank">/chalk</Link>.
          </p>
        </div>
      </div>

      <div className="panel chalk-today">
        <h2 className="panel-title">Today · {fmtDay(today)}</h2>
        {todays ? (
          <>
            <div className="chalk-code">
              <span>Check-in code</span>
              <b>{todays.code}</b>
              <small>{todays.open ? "Open: members enter this at 88risers.com/chalk" : "Closed"}</small>
            </div>
            <p className="muted">
              {todays.attendees} checked in{todays.is_tournament ? " · Tournament" : ""}:{" "}
              {attendees[todayIdx].map((a) => a.display_name).join(", ") || "nobody yet"}
            </p>
            <div className="btn-row">
              <form action={setCheckinOpen}>
                <input type="hidden" name="key" value={k} />
                <input type="hidden" name="meet_id" value={todays.id} />
                <input type="hidden" name="open" value={todays.open ? "0" : "1"} />
                <button className="btn btn-sm">{todays.open ? "Close check-in" : "Reopen check-in"}</button>
              </form>
            </div>
          </>
        ) : (
          <form action={openCheckin} className="btn-row">
            <input type="hidden" name="key" value={k} />
            <label className="check" style={{ margin: 0 }}>
              <input type="checkbox" name="is_tournament" />
              <span>Today is a tournament</span>
            </label>
            <button className="btn btn-primary">Open check-in for today</button>
          </form>
        )}
      </div>

      <div className="admin-rows">
        {meets.map((m, i) => (
          <details key={m.id} className="admin-row" open={m.day === today}>
            <summary>
              <span className="rid">{fmtDay(m.day)}</span>
              <b>{m.is_tournament ? "Tournament" : "Meet"}</b>
              <span className="muted tech">
                {m.attendees} checked in · code {m.code}
              </span>
              {m.open ? <span className="pill">Open</span> : null}
            </summary>
            <p className="muted">{attendees[i].map((a) => a.display_name).join(", ") || "Nobody checked in."}</p>
            <form action={addAttendee} className="btn-row" style={{ marginTop: 10 }}>
              <input type="hidden" name="key" value={k} />
              <input type="hidden" name="meet_id" value={m.id} />
              <AccountSelect name="account_id" options={accts.filter((a) => !attendees[i].some((x) => x.id === a.id))} placeholder="Add a member who was there…" />
              <button className="btn btn-sm">Check them in</button>
            </form>
            <form action={setPodium} className="btn-row" style={{ marginTop: 10 }}>
              <input type="hidden" name="key" value={k} />
              <input type="hidden" name="meet_id" value={m.id} />
              <AccountSelect name="first_id" value={m.first_id} options={attendees[i]} placeholder={`1st (+${CHALK.podium[0]})`} />
              <AccountSelect name="second_id" value={m.second_id} options={attendees[i]} placeholder={`2nd (+${CHALK.podium[1]})`} />
              <AccountSelect name="third_id" value={m.third_id} options={attendees[i]} placeholder={`3rd (+${CHALK.podium[2]})`} />
              <button className="btn btn-sm btn-primary">Save podium</button>
            </form>
            <form action={setMeetTournament} style={{ marginTop: 10 }}>
              <input type="hidden" name="key" value={k} />
              <input type="hidden" name="meet_id" value={m.id} />
              <button className="btn btn-sm btn-ghost">{m.is_tournament ? "Mark as a regular meet" : "Mark as a tournament"}</button>
            </form>
          </details>
        ))}
        {meets.length === 0 ? <div className="panel empty">No meets yet. Open check-in on meet day.</div> : null}
      </div>

      <div className="panel">
        <h2 className="panel-title">The Chalkboard · top 10</h2>
        <ol className="coin-leaders">
          {board.map((r, i) => (
            <li key={r.handle}>
              <span className="cl-rank">{i + 1}</span>
              <span className="cl-name">
                {r.display_name} <span className="muted">@{r.handle}</span>
              </span>
              <b>
                {r.chalk}
                {r.chalk >= settings.target ? " ✓" : ""}
              </b>
            </li>
          ))}
          {board.length === 0 ? <li className="muted">No Chalk yet this season.</li> : null}
        </ol>
        <form action={adjustChalk} className="btn-row" style={{ marginTop: 14 }}>
          <input type="hidden" name="key" value={k} />
          <AccountSelect name="account_id" options={accts} placeholder="Adjust a member's Chalk…" />
          <input name="amount" type="number" placeholder="+/- amount" style={{ width: 120 }} />
          <input name="reason" type="text" placeholder="Reason (shown to them)" />
          <button className="btn btn-sm">Apply</button>
        </form>
      </div>

      <div className="panel">
        <h2 className="panel-title">Settings</h2>
        <form action={saveChalkConfig}>
          <input type="hidden" name="key" value={k} />
          <div className="form-grid">
            <div className="field">
              <label>Lift target <em>Chalk to complete it</em></label>
              <input name="target" type="number" min={1} max={500} defaultValue={settings.target} required />
            </div>
            <div className="field span2">
              <label>Lift prize <em>everyone who completes the Lift</em></label>
              <input name="lift_prize" type="text" defaultValue={settings.liftPrize} />
            </div>
            <div className="field span4">
              <label>Top Riser prize <em>top of the Chalkboard on 31 December</em></label>
              <input name="top_prize" type="text" defaultValue={settings.topPrize} />
            </div>
          </div>
          <button className="btn btn-sm btn-primary">Save settings</button>
        </form>
      </div>
    </>
  );
}
