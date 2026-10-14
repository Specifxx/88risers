import type { Metadata } from "next";
import { JoinForm } from "@/components/JoinForm";
import { getClubStats } from "@/lib/data";
import { SITE, formatId } from "@/lib/site";

export const metadata: Metadata = {
  title: "Register",
  description: "Register with 88 Risers to get texts about meets and tournaments, and claim your permanent Riser ID.",
};

export default async function JoinPage() {
  const stats = await getClubStats();
  return (
    <section className="page-hero join" style={{ paddingBottom: 110 }}>
      <div className="wrap join-grid">
        <div>
          <p className="eyebrow">
            {stats.members} of {SITE.goal} Risers
          </p>
          <h1 className="display">
            Be the
            <br />
            <span className="gold-text">next riser.</span>
          </h1>
          <p className="lede">
            Register and we&apos;ll text you before every meet and tournament. Pull at an event and you&apos;ll be entered
            into the Riser Database — the next number up is <strong>{formatId(stats.next_id)}</strong>.
          </p>
          <ol className="join-steps">
            <li>
              <strong>Register</strong>
              Name, mobile and a photo. No account needed.
            </li>
            <li>
              <strong>Get the text</strong>
              Table time is the first Sunday of every month at {SITE.training.venue}, {SITE.training.timeLabel}.
            </li>
            <li>
              <strong>Pull & get your ID</strong>
              Your record, Elo and match videos live on your Riser profile.
            </li>
          </ol>
        </div>
        <JoinForm nextId={stats.next_id} />
      </div>
    </section>
  );
}
