import type { Metadata } from "next";
import Link from "next/link";
import { BuyButton } from "@/components/BuyButton";
import { GiveawayCounter } from "@/components/GiveawayCounter";
import { currentAccount } from "@/lib/auth";
import { DAILY_GAME_COINS, STORE, WELCOME_COINS, coinLeaders, isRepeatable, itemById, redemptionsOf } from "@/lib/coins";
import { GIVEAWAY_ITEM, getGiveaway } from "@/lib/giveaway";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Rewards",
  description: "Spend 88Risers coins on card frames, titles, club perks and giveaway entries.",
};

const GROUPS = [
  { kind: ["frame", "title", "handle", "badge"], title: "Card cosmetics", note: "Show off on your member pass and the leaderboards." },
  { kind: ["perk"], title: "Club perks", note: "You get a code; show it to an organiser at table time." },
  { kind: ["entry"], title: "Giveaways", note: "Entries into the End of Year Giveaway. More entries, better odds. The winner is drawn by the organisers and announced on Instagram." },
] as const;

export default async function RewardsPage() {
  const me = await currentAccount();
  const [mine, leaders, giveaway] = await Promise.all([me ? redemptionsOf(me.id) : [], coinLeaders(5), getGiveaway(me?.id)]);
  const owned = (id: string) => mine.filter((r) => r.item === id).length;

  return (
    <>
      <section className="page-hero">
        <div className="wrap">
          <p className="crumbs">
            <Link href="/">Home</Link> / Rewards
          </p>
          <h1 className="display">
            Coin <span className="gold-text">store.</span>
          </h1>
          <p className="lede">
            Earn 88Risers coins by calling supermatches ({WELCOME_COINS} free to start, +{DAILY_GAME_COINS} for your first Pin Run
            each day) and spend them here.
          </p>
          <div className="coin-bar">
            {me ? (
              <>
                <span className="coin" aria-hidden />
                <b>{me.coins.toLocaleString("en-AU")}</b> coins
                <Link className="link-arrow" href="/account">
                  Your pass <span>→</span>
                </Link>
              </>
            ) : (
              <>
                <Link className="btn btn-primary btn-sm" href="/account?next=/rewards">
                  Create a free account
                </Link>
                <Link className="link-arrow" href="/account?mode=login&next=/rewards">
                  Log in <span>→</span>
                </Link>
              </>
            )}
          </div>
        </div>
      </section>

      <section className="section" style={{ paddingTop: 40 }}>
        <div className="wrap">
          <GiveawayCounter g={giveaway} loggedIn={!!me} cost={itemById(GIVEAWAY_ITEM)?.cost ?? 0} />
          {GROUPS.map((g) => (
            <div key={g.title} className="store-group">
              <div className="store-head">
                <h2>{g.title}</h2>
                <p className="muted">{g.note}</p>
              </div>
              <div className="store-grid">
                {STORE.filter((i) => (g.kind as readonly string[]).includes(i.kind)).map((i) => {
                  const n = owned(i.id);
                  const maxed = !isRepeatable(i) && n >= i.limit;
                  return (
                    <article key={i.id} id={i.id === GIVEAWAY_ITEM ? GIVEAWAY_ITEM : undefined} className={`store-item store-${i.kind}${i.style ? ` store-${i.style}` : ""}`}>
                      <div className="store-swatch" aria-hidden>
                        {i.kind === "title" ? (
                          <span className="sw-pass">
                            <b>{me?.display_name ?? "Your name"}</b>
                            <em>Hook specialist</em>
                            <small>@{me?.handle ?? "handle"}</small>
                          </span>
                        ) : i.kind === "handle" ? (
                          <span className="sw-handle">
                            <s>@{me?.handle ?? "old_name"}</s>
                            <i>→</i>
                            <b>@new_name</b>
                          </span>
                        ) : null}
                      </div>
                      <h3>{i.name}</h3>
                      <p>{i.blurb}</p>
                      <div className="store-foot">
                        <span className="store-cost">
                          <span className="coin" aria-hidden /> {i.cost}
                        </span>
                        {me ? (
                          maxed ? (
                            <span className="pill">{i.limit === 1 ? "Owned" : `${n}/${i.limit} entries`}</span>
                          ) : (
                            <BuyButton
                              item={i.id}
                              cost={i.cost}
                              needsTitle={i.kind === "title"}
                              needsHandle={i.kind === "handle"}
                              disabled={me.coins < i.cost}
                              label={i.kind === "handle" || (isRepeatable(i) && n) ? `Change · ${i.cost}` : i.kind === "entry" ? `Enter · ${i.cost}${n ? ` (${n} in)` : ""}` : undefined}
                            />
                          )
                        ) : null}
                      </div>
                    </article>
                  );
                })}
              </div>
            </div>
          ))}

          <div className="panel" style={{ maxWidth: 420 }}>
            <h2 className="panel-title">Richest Risers</h2>
            <ol className="coin-leaders">
              {leaders.map((l, i) => (
                <li key={l.handle}>
                  <span className="cl-rank">{i === 0 ? "♛" : i + 1}</span>
                  <Link className="cl-name" href={`/members/${l.handle}`}>
                    {l.display_name}
                    {l.badge ? <i className="cl-lion" aria-label="Lion badge" /> : null}
                  </Link>
                  <b>{l.coins}</b>
                </li>
              ))}
            </ol>
          </div>
          <p className="fine" style={{ marginTop: 28 }}>
            Coins are free play money with no cash value and can&apos;t be bought or transferred. Perks and prizes are
            provided by 88 Risers while stocks last.
          </p>
        </div>
      </section>
    </>
  );
}
