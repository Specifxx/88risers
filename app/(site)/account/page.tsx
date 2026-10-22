import type { Metadata } from "next";
import Link from "next/link";
import { AccountForms } from "@/components/AccountForms";
import { RiserPass } from "@/components/RiserPass";
import { currentAccount } from "@/lib/auth";
import { STORE, coinHistory, itemById, redemptionsOf, styleOf } from "@/lib/coins";
import { fmtShortDate } from "@/lib/schedule";
import { equipFrame, logOut } from "./actions";

export const metadata: Metadata = {
  title: "Account",
  description: "Your 88 Risers account: coins, supermatch picks and rewards.",
  robots: { index: false },
};

export default async function AccountPage({ searchParams }: PageProps<"/account">) {
  const sp = await searchParams;
  const next = typeof sp.next === "string" ? sp.next : "/account";
  const me = await currentAccount();

  if (!me) {
    return (
      <>
        <section className="page-hero">
          <div className="wrap">
            <p className="crumbs">
              <Link href="/">Home</Link> / Account
            </p>
            <h1 className="display">
              Your <span className="gold-text">pass.</span>
            </h1>
            <p className="lede">
              Make supermatch picks, stack 88Risers coins, play Pin Run and unlock rewards. Free, and separate from
              registering for meets.
            </p>
          </div>
        </section>
        <section className="section" style={{ paddingTop: 40 }}>
          <div className="wrap">
            <AccountForms next={next} start={sp.mode === "login" ? "login" : "signup"} />
          </div>
        </section>
      </>
    );
  }

  const [history, style, items] = await Promise.all([coinHistory(me.id), styleOf(me.id), redemptionsOf(me.id)]);
  const ownedFrames = STORE.filter((i) => i.kind === "frame" && items.some((r) => r.item === i.id));

  return (
    <>
      <section className="page-hero">
        <div className="wrap">
          <p className="crumbs">
            <Link href="/">Home</Link> / Account
          </p>
          <h1 className="display">
            G&apos;day, <span className="gold-text">{me.display_name.split(" ")[0]}.</span>
          </h1>
          <div className="btn-row" style={{ marginTop: 24 }}>
            <Link className="btn btn-primary" href="/supermatch">
              Make your pick
            </Link>
            <Link className="btn" href="/rewards">
              Spend coins
            </Link>
            <Link className="btn btn-ghost" href="/play">
              Play Pin Run
            </Link>
            <form action={logOut}>
              <button className="btn btn-ghost">Log out</button>
            </form>
          </div>
        </div>
      </section>

      <section className="section" style={{ paddingTop: 48 }}>
        <div className="wrap account-grid">
          <div>
            <RiserPass name={me.display_name} handle={me.handle} coins={me.coins} style={style} />
            {ownedFrames.length ? (
              <form action={equipFrame} className="frame-pick">
                <label htmlFor="frame">Frame</label>
                <select id="frame" name="frame" defaultValue={style.frame ?? ""}>
                  <option value="">None</option>
                  {ownedFrames.map((f) => (
                    <option key={f.id} value={f.style}>
                      {f.name}
                    </option>
                  ))}
                </select>
                <button className="btn btn-sm">Equip</button>
              </form>
            ) : null}
          </div>

          <div className="account-cols">
            <div className="panel">
              <h2 className="panel-title">Coin history</h2>
              <ul className="ledger">
                {history.map((h, i) => (
                  <li key={i}>
                    <span>{h.reason}</span>
                    <small>{fmtShortDate(new Date(h.created_at))}</small>
                    <b className={h.amount < 0 ? "neg" : "pos"}>
                      {h.amount > 0 ? "+" : ""}
                      {h.amount}
                    </b>
                  </li>
                ))}
              </ul>
            </div>
            <div className="panel">
              <h2 className="panel-title">Your rewards &amp; codes</h2>
              {items.length ? (
                <ul className="ledger">
                  {items.map((r) => (
                    <li key={r.id}>
                      <span>{itemById(r.item)?.name ?? r.item}</span>
                      <small>
                        {r.code}
                        {r.won ? " · WINNER" : r.fulfilled ? " · used" : ""}
                      </small>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="muted">
                  Nothing yet. <Link href="/rewards">Browse the reward store →</Link>
                </p>
              )}
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
