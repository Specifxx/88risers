"use client";

import { startTransition, useActionState } from "react";
import { type FormState, resetPassword, updatePassword } from "@/app/(site)/account/actions";

const onSubmit = (act: (f: FormData) => void) => (e: React.FormEvent<HTMLFormElement>) => {
  e.preventDefault();
  const fd = new FormData(e.currentTarget);
  startTransition(() => act(fd));
};

/** The page a reset link opens: choose a new password. */
export function ResetPasswordForm({ token, handle }: { token: string; handle: string }) {
  const [st, act, pending] = useActionState<FormState, FormData>(resetPassword, { status: "idle" });
  const err = st.status === "error" ? st : null;
  return (
    <form className="form-card on pw-card" onSubmit={onSubmit(act)} noValidate>
      <div className="form-title">
        <h3>New password</h3>
        <span>@{handle}</span>
      </div>
      {err && !err.field ? <div className="form-error">{err.message}</div> : null}
      <input type="hidden" name="token" value={token} />
      <input type="text" name="username" value={handle} autoComplete="username" readOnly hidden />
      <div className="field" data-invalid={err?.field === "password" ? "true" : undefined}>
        <label htmlFor="rp-pass">New password</label>
        <input id="rp-pass" name="password" type="password" autoComplete="new-password" minLength={8} required />
        {err?.field === "password" ? <p className="field-error">{err.message}</p> : <p className="field-hint">At least 8 characters.</p>}
      </div>
      <div className="field" data-invalid={err?.field === "confirm" ? "true" : undefined}>
        <label htmlFor="rp-confirm">Type it again</label>
        <input id="rp-confirm" name="confirm" type="password" autoComplete="new-password" required />
        {err?.field === "confirm" ? <p className="field-error">{err.message}</p> : null}
      </div>
      <button className="btn btn-primary submit" disabled={pending}>
        {pending ? "Saving…" : "Save and log in"}
      </button>
    </form>
  );
}

/** Account page: change your password (you need the current one). */
export function ChangePasswordForm() {
  const [st, act, pending] = useActionState<FormState, FormData>(updatePassword, { status: "idle" });
  const err = st.status === "error" ? st : null;
  return (
    <form className="pw-change" onSubmit={onSubmit(act)} noValidate key={st.status === "ok" ? "done" : "form"}>
      {st.status === "ok" ? <div className="form-ok">{st.message}</div> : null}
      {err && !err.field ? <div className="form-error">{err.message}</div> : null}
      <div className="field" data-invalid={err?.field === "current" ? "true" : undefined}>
        <label htmlFor="cp-cur">Current password</label>
        <input id="cp-cur" name="current" type="password" autoComplete="current-password" required />
        {err?.field === "current" ? <p className="field-error">{err.message}</p> : null}
      </div>
      <div className="field" data-invalid={err?.field === "password" ? "true" : undefined}>
        <label htmlFor="cp-new">New password</label>
        <input id="cp-new" name="password" type="password" autoComplete="new-password" minLength={8} required />
        {err?.field === "password" ? <p className="field-error">{err.message}</p> : <p className="field-hint">At least 8 characters.</p>}
      </div>
      <div className="field" data-invalid={err?.field === "confirm" ? "true" : undefined}>
        <label htmlFor="cp-confirm">Type it again</label>
        <input id="cp-confirm" name="confirm" type="password" autoComplete="new-password" required />
        {err?.field === "confirm" ? <p className="field-error">{err.message}</p> : null}
      </div>
      <button className="btn btn-sm btn-primary" disabled={pending}>
        {pending ? "Saving…" : "Change password"}
      </button>
    </form>
  );
}
