"use client";

import { useActionState, useEffect } from "react";
import { type JoinState, joinAffiliate, resendAffiliateLink } from "@/app/(site)/affiliates/actions";

/** Anyone can sign up: name, a code, where to be paid. Then they land on their private dashboard. */
export function AffiliateJoin() {
  const [state, action, pending] = useActionState<JoinState, FormData>(joinAffiliate, { status: "idle" });
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
        <label htmlFor="a-email">PayPal email (for your commission and your dashboard link)</label>
        <input id="a-email" name="email" type="email" autoComplete="email" maxLength={120} />
      </div>
      <div className="field">
        <label htmlFor="a-phone">Mobile</label>
        <input id="a-phone" name="phone" type="tel" autoComplete="tel" placeholder="0412 345 678" />
      </div>
      <div className="hp" aria-hidden>
        <label>
          Company <input name="company" type="text" tabIndex={-1} autoComplete="off" />
        </label>
      </div>
      <label className="check">
        <input type="checkbox" name="agree" />
        <span>I agree: commission is paid monthly by PayPal for paid, un-refunded orders, and I can&apos;t use my own code.</span>
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
