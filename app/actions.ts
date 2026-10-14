"use server";

import { getDb } from "@/lib/db";
import { normalisePhone } from "@/lib/phone";
import { savePhoto } from "@/lib/photos";

export type JoinState =
  | { status: "idle" }
  | { status: "error"; message: string; field?: "name" | "phone" | "photo" | "consent" }
  | { status: "ok"; name: string; updated: boolean };

export async function register(_prev: JoinState, form: FormData): Promise<JoinState> {
  // Honeypot: real people never see or fill this field.
  if (String(form.get("company") ?? "").trim()) return { status: "ok", name: "", updated: false };

  const name = String(form.get("name") ?? "").trim().replace(/\s+/g, " ");
  const phone = normalisePhone(String(form.get("phone") ?? ""));
  const instagram = String(form.get("instagram") ?? "").trim().replace(/^@/, "").slice(0, 60) || null;
  const consent = form.get("consent") === "on";

  if (name.length < 2 || name.length > 80) return { status: "error", field: "name", message: "Tell us your full name." };
  if (!phone)
    return { status: "error", field: "phone", message: "That number doesn't look right — try something like 0412 345 678." };
  if (!consent)
    return { status: "error", field: "consent", message: "Tick the box so we can text you event details." };

  try {
    const db = await getDb();
    return await db.transaction(async (tx) => {
      const photo = await savePhoto(tx, form.get("photo"), false);
      if (photo && "error" in photo) return { status: "error", field: "photo", message: photo.error } as const;
      if (!photo) return { status: "error", field: "photo", message: "Add a photo so we can recognise you at the table." } as const;

      const [row] = await tx.query<{ inserted: boolean }>(
        `INSERT INTO registrations (name, phone, instagram, photo_id, sms_consent)
         VALUES ($1, $2, $3, $4, true)
         ON CONFLICT (phone) DO UPDATE SET
           name = EXCLUDED.name,
           instagram = coalesce(EXCLUDED.instagram, registrations.instagram),
           photo_id = EXCLUDED.photo_id,
           sms_consent = true,
           updated_at = now()
         RETURNING (xmax = 0) AS inserted`,
        [name, phone, instagram, photo.id],
      );
      return { status: "ok", name: name.split(" ")[0], updated: !row.inserted } as const;
    });
  } catch (err) {
    console.error("register failed", err);
    return { status: "error", message: "Something went wrong on our side. Try again, or DM us on Instagram." };
  }
}
