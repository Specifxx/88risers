"use client";

import { useState } from "react";

/** A link shown in full with a Copy button (falls back to selecting it if the clipboard is blocked). */
export function CopyText({ text }: { text: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <div className="copy-text">
      <input readOnly value={text} onFocus={(e) => e.currentTarget.select()} aria-label="Share link" />
      <button
        type="button"
        className="btn btn-sm btn-primary"
        onClick={async () => {
          try {
            await navigator.clipboard.writeText(text);
            setCopied(true);
            setTimeout(() => setCopied(false), 1800);
          } catch {}
        }}
      >
        {copied ? "Copied ✓" : "Copy"}
      </button>
    </div>
  );
}
