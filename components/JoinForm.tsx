"use client";

import { startTransition, useActionState, useRef, useState } from "react";
import { register, type JoinState } from "@/app/actions";
import { SITE } from "@/lib/site";
import { Arrow, Camera, Check, Instagram } from "./Icons";
import { shrinkImage as shrink } from "@/lib/shrink";

export function JoinForm({ nextId }: { nextId: number }) {
  const [state, action, pending] = useActionState<JoinState, FormData>(register, { status: "idle" });
  const [preview, setPreview] = useState<string | null>(null);
  const [drag, setDrag] = useState(false);
  const [photoBusy, setPhotoBusy] = useState(false);
  const photo = useRef<File | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  async function pick(file: File | undefined) {
    if (!file) return;
    setPhotoBusy(true);
    const small = await shrink(file);
    photo.current = small;
    setPreview((old) => {
      if (old) URL.revokeObjectURL(old);
      return URL.createObjectURL(small);
    });
    setPhotoBusy(false);
  }

  // Submit manually (not via the form's action prop) so React doesn't reset the
  // fields when the server sends back a validation error.
  function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    if (photo.current) fd.set("photo", photo.current);
    startTransition(() => action(fd));
  }

  if (state.status === "ok") {
    return (
      <div className="form-card" aria-live="polite">
        <div className="success">
          <div className="tick">
            <Check />
          </div>
          <h3>{state.updated ? "Details updated" : `You're in${state.name ? `, ${state.name}` : ""}`}</h3>
          <p>
            We&apos;ll text you before the next meet with everything you need. Pull at one of our events and you&apos;ll be
            entered into the Riser Database with your own permanent ID.
          </p>
          <a className="ig-card" href={SITE.instagramUrl} target="_blank" rel="noreferrer">
            <Instagram />
            <div>
              <b>Last step: follow @{SITE.instagramHandle}</b>
              <span>Event drops, results and match videos land there first.</span>
            </div>
            <i>FOLLOW</i>
          </a>
        </div>
      </div>
    );
  }

  const err = state.status === "error" ? state : null;
  const invalid = (f: string) => (err?.field === f ? "true" : undefined);

  return (
    <form className="form-card" onSubmit={submit} noValidate>
      <div className="form-title">
        <h3>Register</h3>
        <span>Next ID · #{String(nextId).padStart(3, "0")}</span>
      </div>

      {err && !err.field ? (
        <div className="form-error" role="alert">
          {err.message}
        </div>
      ) : null}

      <div className="field" data-invalid={invalid("name")}>
        <label htmlFor="j-name">Full name</label>
        <input id="j-name" name="name" type="text" autoComplete="name" placeholder="Your name" required maxLength={80} />
        {err?.field === "name" ? <p className="field-error">{err.message}</p> : null}
      </div>

      <div className="field" data-invalid={invalid("phone")}>
        <label htmlFor="j-phone">Mobile number</label>
        <input
          id="j-phone"
          name="phone"
          type="tel"
          inputMode="tel"
          autoComplete="tel"
          placeholder="0412 345 678"
          required
        />
        {err?.field === "phone" ? (
          <p className="field-error">{err.message}</p>
        ) : (
          <p className="field-hint">We text event details. No spam, ever.</p>
        )}
      </div>

      <div className="field" data-invalid={invalid("photo")}>
        <span className="label">
          Photo <em>so we know who you are</em>
        </span>
        <label
          className="dropzone"
          data-drag={drag}
          onDragOver={(e) => {
            e.preventDefault();
            setDrag(true);
          }}
          onDragLeave={() => setDrag(false)}
          onDrop={(e) => {
            e.preventDefault();
            setDrag(false);
            pick(e.dataTransfer.files?.[0]);
          }}
        >
          <input
            ref={fileInput}
            type="file"
            accept="image/jpeg,image/png,image/webp,image/heic,image/heif"
            aria-label="Upload a photo of yourself"
            onChange={(e) => pick(e.target.files?.[0])}
          />
          <div className="thumb">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            {preview ? <img src={preview} alt="Your photo preview" /> : <Camera />}
          </div>
          <div>
            <b>{photoBusy ? "Processing…" : preview ? "Looking good — tap to change" : "Add a clear face photo"}</b>
            <span>Take one now or choose from your camera roll.</span>
          </div>
        </label>
        {err?.field === "photo" ? <p className="field-error">{err.message}</p> : null}
      </div>

      <div className="field">
        <label htmlFor="j-ig">
          Instagram <em>optional</em>
        </label>
        <input id="j-ig" name="instagram" type="text" placeholder="@yourhandle" autoCapitalize="off" autoCorrect="off" />
      </div>

      <div className="hp" aria-hidden>
        <label>
          Company <input name="company" type="text" tabIndex={-1} autoComplete="off" />
        </label>
      </div>

      <label className="check">
        <input type="checkbox" name="consent" defaultChecked />
        <span>
          Text me about 88 Risers meets and tournaments. I can reply STOP any time.
          {err?.field === "consent" ? <span className="field-error" style={{ display: "block" }}>{err.message}</span> : null}
        </span>
      </label>

      <button className="btn btn-primary submit" type="submit" disabled={pending || photoBusy}>
        {pending ? "Registering…" : "Claim my spot"} {!pending ? <Arrow /> : null}
      </button>
      <p className="fine">
        Your number and photo stay private to the club organisers. If you compete, your name, photo and results appear on
        your public Riser profile.
      </p>
    </form>
  );
}
