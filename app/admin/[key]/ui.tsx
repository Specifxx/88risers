"use client";

import { useState } from "react";
import { shrinkImage } from "@/lib/shrink";

export function ConfirmButton({ message, children, className = "btn btn-sm btn-ghost" }: { message: string; children: React.ReactNode; className?: string }) {
  return (
    <button
      type="submit"
      className={className}
      onClick={(e) => {
        if (!confirm(message)) e.preventDefault();
      }}
    >
      {children}
    </button>
  );
}

export function CopyButton({ text, label }: { text: string; label: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <button
      type="button"
      className="btn btn-sm"
      onClick={async () => {
        await navigator.clipboard.writeText(text);
        setCopied(true);
        setTimeout(() => setCopied(false), 1800);
      }}
    >
      {copied ? "Copied ✓" : label}
    </button>
  );
}

/** File input that downsizes the chosen image before the form is submitted. */
export function ImageInput({ name, max = 1600 }: { name: string; max?: number }) {
  const [note, setNote] = useState<string | null>(null);
  return (
    <>
      <input
        type="file"
        name={name}
        accept="image/jpeg,image/png,image/webp"
        className="input"
        style={{ padding: 12 }}
        onChange={async (e) => {
          const input = e.currentTarget;
          const file = input.files?.[0];
          if (!file) return;
          setNote("Resizing…");
          const small = await shrinkImage(file, max);
          const dt = new DataTransfer();
          dt.items.add(small);
          input.files = dt.files;
          setNote(`Ready · ${Math.round(small.size / 1024)} KB`);
        }}
      />
      {note ? <p className="field-hint">{note}</p> : null}
    </>
  );
}
