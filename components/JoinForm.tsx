"use client";

import { startTransition, useActionState, useEffect, useRef, useState } from "react";
import { lionSays } from "@/lib/lion";
import { register, type JoinState } from "@/app/actions";
import { SITE } from "@/lib/site";
import { Arrow, Camera, Check, Instagram } from "./Icons";
import { shrinkImage as shrink } from "@/lib/shrink";

/** Riser numbers anyone can pick for a $2 gold coin donation (kept in sync with lib/data). */
const PICK_MIN = 9;
const PICK_MAX = 87;
const pad = (n: number) => String(n).padStart(3, "0");

export function JoinForm({ nextId, unavailable = [] }: { nextId: number; unavailable?: number[] }) {
  const [state, action, pending] = useActionState<JoinState, FormData>(register, { status: "idle" });
  const [preview, setPreview] = useState<string | null>(null);
  const [drag, setDrag] = useState(false);
  const [photoBusy, setPhotoBusy] = useState(false);
  const [pickOn, setPickOn] = useState(false);
  const [pickNum, setPickNum] = useState("");
  const [taken, setTaken] = useState<number[]>(unavailable);
  // The page is cached, so fetch fresh availability once someone opens the picker.
  useEffect(() => {
    if (!pickOn) return;
    fetch("/api/riser-ids")
      .then((r) => (r.ok ? r.json() : null))
      .then((d) => d && Array.isArray(d.unavailable) && setTaken(d.unavailable))
      .catch(() => {});
  }, [pickOn]);
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

  useEffect(() => {
    if (state.status === "ok" && !state.updated) lionSays("roar", `ROAR! Welcome${state.name ? `, ${state.name}` : ""}.`);
  }, [state]);

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
          {state.requested ? (
            <p className="pick-confirm">
              <b>#{pad(state.requested)} is held for you.</b> Bring a $2 gold coin donation to your first meet and it&apos;s
              yours.
            </p>
          ) : null}
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

      <div className="field pick-field" data-invalid={invalid("requested_id")}>
        <label className="check" style={{ margin: 0 }}>
          <input type="checkbox" checked={pickOn} onChange={(e) => setPickOn(e.target.checked)} />
          <span>
            I want a specific Riser number <em>$2 gold coin donation</em>
          </span>
        </label>
        {pickOn ? (
          <>
            <div className="pick-row">
              <span className="pick-hash">#</span>
              <input
                name="requested_id"
                type="number"
                inputMode="numeric"
                min={PICK_MIN}
                max={PICK_MAX}
                placeholder={pad(PICK_MIN + 33)}
                value={pickNum}
                onChange={(e) => setPickNum(e.target.value.slice(0, 2))}
                aria-label={`Riser number from ${PICK_MIN} to ${PICK_MAX}`}
              />
              {(() => {
                const n = Number(pickNum);
                if (!pickNum) return <span className="pick-status">Choose {pad(PICK_MIN)}–{pad(PICK_MAX)}</span>;
                if (!Number.isInteger(n) || n < PICK_MIN || n > PICK_MAX)
                  return <span className="pick-status bad">Pick {PICK_MIN}–{PICK_MAX}</span>;
                return taken.includes(n) ? (
                  <span className="pick-status bad">#{pad(n)} is taken</span>
                ) : (
                  <span className="pick-status ok">#{pad(n)} is available ✓</span>
                );
              })()}
            </div>
            {err?.field === "requested_id" ? (
              <p className="field-error">{err.message}</p>
            ) : (
              <p className="field-hint">
                We hold it for you; drop a $2 gold coin in the club tin at your first meet. Otherwise you get the next
                number, #{pad(nextId)}. #001–#008 are the founders and #088 is reserved.
              </p>
            )}
          </>
        ) : null}
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
