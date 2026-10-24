"use client";

import { useRouter } from "next/navigation";
import { startTransition, useActionState, useEffect } from "react";
import { type FormState, buyItem } from "@/app/(site)/account/actions";
import { lionSays } from "@/lib/lion";

export function BuyButton({
  item,
  cost,
  needsTitle,
  needsHandle,
  disabled,
  label,
}: {
  item: string;
  cost: number;
  needsTitle?: boolean;
  needsHandle?: boolean;
  disabled?: boolean;
  label?: string;
}) {
  const [state, action, pending] = useActionState<FormState, FormData>(buyItem, { status: "idle" });
  const router = useRouter();
  useEffect(() => {
    if (state.status !== "ok") return;
    lionSays("cheer", "Nice haul. Wear it with pride.");
    // Keep the confirmation (and any code) on screen, then refresh balances.
    const t = setTimeout(() => router.refresh(), needsTitle ? 1500 : 4000);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [state]);
  return (
    <form
      className="buy"
      onSubmit={(e) => {
        e.preventDefault();
        const fd = new FormData(e.currentTarget);
        startTransition(() => action(fd));
      }}
    >
      <input type="hidden" name="item" value={item} />
      {needsTitle ? <input name="title" placeholder="Your title, e.g. Hook specialist" maxLength={32} className="buy-title" /> : null}
      {needsHandle ? (
        <input
          name="handle"
          placeholder="new_handle"
          maxLength={21}
          autoCapitalize="none"
          autoCorrect="off"
          spellCheck={false}
          pattern="@?[A-Za-z0-9_]{3,20}"
          title="3–20 letters, numbers or underscores"
          className="buy-title"
          aria-label="Your new handle"
        />
      ) : null}
      <button className="btn btn-sm btn-primary" disabled={disabled || pending}>
        {pending ? "…" : (label ?? `Unlock · ${cost}`)}
      </button>
      {state.status === "error" ? <p className="field-error">{state.message}</p> : null}
      {state.status === "ok" ? <p className="buy-ok">{state.message}</p> : null}
    </form>
  );
}
