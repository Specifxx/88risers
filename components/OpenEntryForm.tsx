"use client";

import { startTransition, useActionState } from "react";
import { enterOpen, type OpenState } from "@/app/(site)/rhodes-open/actions";
import { ARMS_LABEL, OPEN, classLabel } from "@/lib/rhodesOpenConfig";
import { SITE } from "@/lib/site";
import { Arrow, Check, Instagram } from "./Icons";

/** Rhodes Open entry: name, mobile, arms, weight class. Nothing to pay yet. */
export function OpenEntryForm() {
  const [state, action, pending] = useActionState<OpenState, FormData>(enterOpen, { status: "idle" });

  function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    startTransition(() => action(fd));
  }

  if (state.status === "ok") {
    return (
      <div className="form-card" aria-live="polite">
        <div className="success">
          <div className="tick">
            <Check />
          </div>
          <h3>{state.updated ? "Entry updated" : `You're on the list${state.name ? `, ${state.name}` : ""}`}</h3>
          <p>
            {ARMS_LABEL[state.arms]} · {classLabel(state.weightClass)}. Nothing to pay yet: we&apos;ll text you once the
            details are locked in, with how to pay and the early bird price.
          </p>
          <p className="fine">Entered the wrong thing? Fill the form in again with the same mobile number and it updates.</p>
          <a className="ig-card" href={SITE.instagramUrl} target="_blank" rel="noreferrer">
            <Instagram />
            <div>
              <b>Follow @{SITE.instagramHandle}</b>
              <span>Brackets, weigh-in times and the coin reveal land there first.</span>
            </div>
            <i>FOLLOW</i>
          </a>
        </div>
      </div>
    );
  }

  const err = state.status === "error" ? state : null;
  const invalid = (f: string) => (err?.field === f ? "true" : undefined);
  const fieldErr = (f: string) => (err?.field === f ? <p className="field-error">{err.message}</p> : null);

  return (
    <form className="form-card" onSubmit={submit} noValidate id="enter">
      <div className="form-title">
        <h3>Enter</h3>
        <span>No payment yet</span>
      </div>
      {err && !err.field ? (
        <div className="form-error" role="alert">
          {err.message}
        </div>
      ) : null}

      <div className="field" data-invalid={invalid("name")}>
        <label htmlFor="o-name">Full name</label>
        <input id="o-name" name="name" type="text" autoComplete="name" placeholder="Your name" required maxLength={80} />
        {fieldErr("name")}
      </div>
      <div className="field" data-invalid={invalid("phone")}>
        <label htmlFor="o-phone">Mobile number</label>
        <input id="o-phone" name="phone" type="tel" inputMode="tel" autoComplete="tel" placeholder="0412 345 678" required />
        {fieldErr("phone") ?? <p className="field-hint">We text brackets, weigh-in times and payment details.</p>}
      </div>

      <div className="field" data-invalid={invalid("arms")}>
        <span className="label">Arm</span>
        <div className="open-seg">
          {(["right", "left", "both"] as const).map((a) => (
            <label key={a}>
              <input type="radio" name="arms" value={a} defaultChecked={a === "right"} />
              <span>{ARMS_LABEL[a]}</span>
            </label>
          ))}
        </div>
        {fieldErr("arms")}
      </div>
      <div className="field" data-invalid={invalid("weight_class")}>
        <label htmlFor="o-class">Weight class</label>
        <select id="o-class" name="weight_class" defaultValue="">
          <option value="" disabled>
            Pick your class
          </option>
          {OPEN.classes.map((c) => (
            <option key={c} value={c}>
              {classLabel(c)}
            </option>
          ))}
        </select>
        {fieldErr("weight_class") ?? <p className="field-hint">Your best guess is fine: you can change it before weigh-ins.</p>}
      </div>

      <div className="open-two">
        <div className="field" data-invalid={invalid("riser_id")}>
          <label htmlFor="o-riser">
            Riser ID <em>if you have one</em>
          </label>
          <input id="o-riser" name="riser_id" type="text" inputMode="numeric" placeholder="e.g. 017" maxLength={5} />
          {fieldErr("riser_id")}
        </div>
        <div className="field">
          <label htmlFor="o-ig">
            Instagram <em>optional</em>
          </label>
          <input id="o-ig" name="instagram" type="text" placeholder="@yourhandle" autoCapitalize="off" autoCorrect="off" />
        </div>
      </div>
      <div className="field" data-invalid={invalid("email")}>
        <label htmlFor="o-email">
          Email <em>optional</em>
        </label>
        <input id="o-email" name="email" type="email" autoComplete="email" placeholder="you@example.com" />
        {fieldErr("email")}
      </div>
      <div className="field">
        <label htmlFor="o-notes">
          Anything we should know? <em>optional</em>
        </label>
        <textarea id="o-notes" name="notes" rows={2} maxLength={400} placeholder="Club, experience, injuries, coming with friends…" />
      </div>

      <div className="hp" aria-hidden>
        <label>
          Company <input name="company" type="text" tabIndex={-1} autoComplete="off" />
        </label>
      </div>
      <label className="check">
        <input type="checkbox" name="adult" />
        <span>
          I&apos;m 18 or over, and I&apos;ll sign the waiver at check-in.
          {err?.field === "adult" ? <span className="field-error" style={{ display: "block" }}>{err.message}</span> : null}
        </span>
      </label>

      <button className="btn btn-primary submit" type="submit" disabled={pending}>
        {pending ? "Entering…" : "Enter the Rhodes Open"} {!pending ? <Arrow /> : null}
      </button>
      <p className="fine">
        This holds your spot while the event is in draft. Your number and email stay private to the club organisers. By
        entering you agree to our <a href="/conduct">Code of Conduct</a>.
      </p>
    </form>
  );
}
