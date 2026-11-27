"use client";

import { useActionState, useEffect, useState } from "react";
import { type JoinState, joinAffiliate, resendAffiliateLink } from "@/app/(site)/affiliates/actions";

/** Anyone can sign up: name, a code, where to be paid. Then they land on their private dashboard. */
export function AffiliateJoin() {
  const [state, action, pending] = useActionState<JoinState, FormData>(joinAffiliate, { status: "idle" });
  const [method, setMethod] = useState<"paypal" | "bank">("paypal");
  useEffect(() => {
    if (state.status === "ok") window.location.href = `/affiliates?t=${state.token}&new=1`;
  }, [state]);
  return (
    <form action={action} className="form-card">
      <div className="form-title">
        <h3>Become an affiliate</h3>
        <span>Free · anyone can join</span>
      </div>
      {state.status === "error" ? (
        <div className="form-error" role="alert">
          {state.message}
        </div>
      ) : null}
      <div className="field">
        <label htmlFor="a-name">Your name</label>
        <input id="a-name" name="name" type="text" autoComplete="name" maxLength={80} />
      </div>
      <div className="field">
        <label htmlFor="a-code">Your code</label>
        <input id="a-code" name="code" type="text" maxLength={15} autoCapitalize="characters" placeholder="e.g. HARRY" />
        <p className="field-hint">3–15 letters or numbers. Short and easy to say.</p>
      </div>
      <div className="field">
        <label htmlFor="a-email">Email (we send your dashboard link here)</label>
        <input id="a-email" name="email" type="email" autoComplete="email" maxLength={120} />
      </div>
      <div className="field">
        <label htmlFor="a-phone">Mobile</label>
        <input id="a-phone" name="phone" type="tel" autoComplete="tel" placeholder="0412 345 678" />
      </div>
      <div className="field">
        <label>How should we pay your commission?</label>
        <div role="radiogroup" style={{ display: "flex", flexWrap: "wrap", gap: 4 }}>
          <label className="check" style={{ marginRight: 16 }}>
            <input type="radio" name="method" value="paypal" checked={method === "paypal"} onChange={() => setMethod("paypal")} />
            <span>PayPal (to the email above)</span>
          </label>
          <label className="check">
            <input type="radio" name="method" value="bank" checked={method === "bank"} onChange={() => setMethod("bank")} />
            <span>Bank transfer</span>
          </label>
        </div>
      </div>
      {method === "bank" ? (
        <>
          <div className="field">
            <label htmlFor="a-bank-name">Name on the account</label>
            <input id="a-bank-name" name="bank_name" type="text" maxLength={80} autoComplete="off" />
          </div>
          <div className="field">
            <label htmlFor="a-bsb">BSB</label>
            <input id="a-bsb" name="bsb" type="text" inputMode="numeric" maxLength={7} placeholder="062-000" autoComplete="off" />
          </div>
          <div className="field">
            <label htmlFor="a-account">Account number</label>
            <input id="a-account" name="account" type="text" inputMode="numeric" maxLength={12} autoComplete="off" />
            <p className="field-hint">Any Australian bank account. Only the club organisers can see these details.</p>
          </div>
        </>
      ) : null}
      <div className="hp" aria-hidden>
        <label>
          Company <input name="company" type="text" tabIndex={-1} autoComplete="off" />
        </label>
      </div>
      <label className="check">
        <input type="checkbox" name="agree" />
        <span>
          I agree to the <a href="/terms#affiliates">affiliate terms</a>: I&apos;ll disclose that I earn commission when I share my code (e.g.
          #ad), commission is paid monthly for paid, un-refunded orders, and I can&apos;t use my own code.
        </span>
      </label>
      <button className="btn btn-primary submit" type="submit" disabled={pending}>
        {pending ? "Saving…" : "Get my code"}
      </button>
    </form>
  );
}

/** Lost the dashboard link: email it again (same answer whether or not the email is signed up). */
export function AffiliateResend() {
  const [state, action, pending] = useActionState(resendAffiliateLink, { sent: false });
  return state.sent ? (
    <p className="muted">If that email is signed up, your dashboard link is on its way.</p>
  ) : (
    <form action={action} className="code-row" style={{ maxWidth: 420 }}>
      <input name="email" type="email" placeholder="Your affiliate email" className="input" required />
      <button className="btn btn-sm btn-ghost" disabled={pending}>
        Email my link
      </button>
    </form>
  );
}
