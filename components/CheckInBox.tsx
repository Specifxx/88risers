"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useActionState, useEffect } from "react";
import { type FormState, checkIn } from "@/app/(site)/account/actions";
import { lionSays } from "@/lib/lion";

/** Meet-day check-in: enter the code shown at the table for Chalk. */
export function CheckInBox({ loggedIn, already, points }: { loggedIn: boolean; already: boolean; points: number }) {
  const [state, action, pending] = useActionState<FormState, FormData>(checkIn, { status: "idle" });
  const router = useRouter();

  useEffect(() => {
    if (state.status !== "ok") return;
    lionSays("roar", "Checked in. Chalk up!");
    const t = setTimeout(() => router.refresh(), 1600);
    return () => clearTimeout(t);
  }, [state, router]);

  if (already) {
    return (
      <div className="checkin done">
        <b>You&apos;re checked in today ✓</b>
        <span>+{points} Chalk is on your Lift. Enjoy the meet!</span>
      </div>
    );
  }
  if (!loggedIn) {
    return (
      <div className="checkin">
        <b>Meet today: check in for +{points} Chalk</b>
        <span>
          <Link href="/account?next=/chalk">Log in or create a free account</Link> to check in.
        </span>
      </div>
    );
  }
  return (
    <form className="checkin" action={action}>
      <b>Meet today: check in for +{points} Chalk</b>
      <span>Enter the 4-digit code shown at the table.</span>
      <div className="checkin-row">
        <input name="code" inputMode="numeric" pattern="[0-9]*" maxLength={4} placeholder="0000" aria-label="Check-in code" required autoComplete="off" />
        <button className="btn btn-primary" disabled={pending || state.status === "ok"}>
          {pending ? "Checking…" : "Check in"}
        </button>
      </div>
      {state.status === "error" ? <div className="form-error">{state.message}</div> : null}
      {state.status === "ok" ? <div className="form-ok">{state.message}</div> : null}
    </form>
  );
}
