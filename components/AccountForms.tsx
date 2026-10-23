"use client";

import { startTransition, useActionState, useState } from "react";
import { type FormState, logIn, signUp } from "@/app/(site)/account/actions";
import { Arrow } from "./Icons";

/** Sign up / log in, side by side on desktop, tabbed on phones. */
export function AccountForms({ next, start = "signup" }: { next: string; start?: "signup" | "login" }) {
  const [tab, setTab] = useState(start);
  const [up, upAction, upPending] = useActionState<FormState, FormData>(signUp, { status: "idle" });
  const [inn, inAction, inPending] = useActionState<FormState, FormData>(logIn, { status: "idle" });
  const submit = (act: (f: FormData) => void) => (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    startTransition(() => act(fd));
  };
  const upErr = up.status === "error" ? up : null;
  const inErr = inn.status === "error" ? inn : null;

  return (
    <div className="auth">
      <div className="auth-tabs" role="tablist">
        <button type="button" role="tab" aria-selected={tab === "signup"} onClick={() => setTab("signup")}>
          Create account
        </button>
        <button type="button" role="tab" aria-selected={tab === "login"} onClick={() => setTab("login")}>
          Log in
        </button>
      </div>
      <div className="auth-grid">
        <form className={`form-card${tab === "signup" ? " on" : ""}`} onSubmit={submit(upAction)} noValidate>
          <div className="form-title">
            <h3>Create your account</h3>
            <span>+25 coins to start</span>
          </div>
          {upErr && !upErr.field ? <div className="form-error">{upErr.message}</div> : null}
          <input type="hidden" name="next" value={next} />
          <div className="field" data-invalid={upErr?.field === "display_name" ? "true" : undefined}>
            <label htmlFor="su-name">Your name</label>
            <input id="su-name" name="display_name" autoComplete="name" placeholder="Shown on leaderboards" maxLength={40} required />
            {upErr?.field === "display_name" ? <p className="field-error">{upErr.message}</p> : null}
          </div>
          <div className="field" data-invalid={upErr?.field === "handle" ? "true" : undefined}>
            <label htmlFor="su-handle">Username</label>
            <input id="su-handle" name="handle" autoComplete="username" placeholder="e.g. hook_master" autoCapitalize="off" autoCorrect="off" maxLength={20} required />
            {upErr?.field === "handle" ? <p className="field-error">{upErr.message}</p> : <p className="field-hint">Letters, numbers and underscores.</p>}
          </div>
          <div className="field" data-invalid={upErr?.field === "password" ? "true" : undefined}>
            <label htmlFor="su-pass">Password</label>
            <input id="su-pass" name="password" type="password" autoComplete="new-password" minLength={8} required />
            {upErr?.field === "password" ? <p className="field-error">{upErr.message}</p> : <p className="field-hint">At least 8 characters.</p>}
          </div>
          <div className="field" data-invalid={upErr?.field === "invited_by" ? "true" : undefined}>
            <label htmlFor="su-invite">
              Invited by <em>optional</em>
            </label>
            <input id="su-invite" name="invited_by" placeholder="@their_username" autoCapitalize="off" autoCorrect="off" maxLength={21} />
            {upErr?.field === "invited_by" ? (
              <p className="field-error">{upErr.message}</p>
            ) : (
              <p className="field-hint">They get bonus Chalk when you come to your first meet.</p>
            )}
          </div>
          <div className="hp" aria-hidden>
            <label>
              Company <input name="company" type="text" tabIndex={-1} autoComplete="off" />
            </label>
          </div>
          <button className="btn btn-primary submit" disabled={upPending}>
            {upPending ? "Creating…" : "Create account"} {!upPending ? <Arrow /> : null}
          </button>
          <p className="fine">Coins are free play money for predictions and rewards. They can&apos;t be bought or cashed out.</p>
        </form>

        <form className={`form-card${tab === "login" ? " on" : ""}`} onSubmit={submit(inAction)} noValidate>
          <div className="form-title">
            <h3>Welcome back</h3>
          </div>
          {inErr ? <div className="form-error">{inErr.message}</div> : null}
          <input type="hidden" name="next" value={next} />
          <div className="field">
            <label htmlFor="li-handle">Username</label>
            <input id="li-handle" name="handle" autoComplete="username" autoCapitalize="off" autoCorrect="off" required />
          </div>
          <div className="field">
            <label htmlFor="li-pass">Password</label>
            <input id="li-pass" name="password" type="password" autoComplete="current-password" required />
          </div>
          <button className="btn btn-primary submit" disabled={inPending}>
            {inPending ? "Logging in…" : "Log in"} {!inPending ? <Arrow /> : null}
          </button>
          <p className="fine">Forgot your password? Message us on Instagram and an organiser will reset it.</p>
        </form>
      </div>
    </div>
  );
}
