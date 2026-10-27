import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { LogBook, type LogEntry } from "@/components/LogBook";
import { currentAccount } from "@/lib/auth";
import { sydneyToday } from "@/lib/chalk";
import { getDb } from "@/lib/db";

export const metadata: Metadata = { title: "Training log", robots: { index: false } };
export const dynamic = "force-dynamic";

/** The 3-month block the log is built around. */
const BLOCK_DAYS = 90;
const DAY = 86_400_000;
const daysBetween = (a: string, b: string) => Math.round((Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`)) / DAY);

export default async function LogPage() {
  const me = await currentAccount();
  if (!me) redirect("/account?next=/log");
  const db = await getDb();
  const entries = await db.query<LogEntry>(
    `SELECT id, to_char(logged_on, 'YYYY-MM-DD') AS day, body FROM training_log WHERE account_id = $1 ORDER BY logged_on DESC, id DESC`,
    [me.id],
  );
  const today = sydneyToday();
  const first = entries.length ? entries[entries.length - 1].day : null;
  const dayN = first ? daysBetween(first, today) + 1 : 0;
  const daysLogged = new Set(entries.map((e) => e.day)).size;
  const thisWeek = new Set(entries.filter((e) => daysBetween(e.day, today) < 7).map((e) => e.day)).size;
  const pct = Math.min(100, Math.round((Math.min(dayN, BLOCK_DAYS) / BLOCK_DAYS) * 100));

  return (
    <>
      <section className="page-hero" style={{ paddingBottom: 16 }}>
        <div className="wrap">
          <p className="crumbs">
            <Link href="/">Home</Link> / <Link href="/account">Account</Link> / Log
          </p>
          <h1 className="display">
            Training <span className="gold-text">log.</span>
          </h1>
          <p className="lede">
            Write down every session: what you trained, the numbers, how it felt. Three months of honest notes shows patterns you won&apos;t
            notice day to day. Download it any time to look back over it, or to paste into an AI and ask what stands out.
          </p>
          <div className="log-stats">
            <div>
              <b>{dayN ? `Day ${Math.min(dayN, 999)}` : "Day 0"}</b>
              <span>of {BLOCK_DAYS}</span>
            </div>
            <div>
              <b>{daysLogged}</b>
              <span>days logged</span>
            </div>
            <div>
              <b>{entries.length}</b>
              <span>{entries.length === 1 ? "entry" : "entries"}</span>
            </div>
            <div>
              <b>{thisWeek}</b>
              <span>this week</span>
            </div>
          </div>
          <div className="log-bar" role="img" aria-label={`${pct}% of the ${BLOCK_DAYS}-day block`}>
            <i style={{ width: `${pct}%` }} />
          </div>
        </div>
      </section>
      <section className="section" style={{ paddingTop: 8 }}>
        <div className="wrap">
          <LogBook entries={entries} today={today} />
        </div>
      </section>
    </>
  );
}
