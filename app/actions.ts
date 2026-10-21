"use server";

import { getDb } from "@/lib/db";
import { sendClubMail } from "@/lib/mail";
import { normalisePhone, prettyPhone } from "@/lib/phone";
import { productById } from "@/lib/shop";
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

/* ─────────── Shop: register interest ─────────── */

export type InterestState =
  | { status: "idle" }
  | { status: "error"; message: string; field?: "name" | "phone" }
  | { status: "ok"; name: string };

export async function registerInterest(_prev: InterestState, form: FormData): Promise<InterestState> {
  if (String(form.get("company") ?? "").trim()) return { status: "ok", name: "" };

  const product = productById(String(form.get("product") ?? ""));
  const name = String(form.get("name") ?? "").trim().replace(/\s+/g, " ");
  const phone = normalisePhone(String(form.get("phone") ?? ""));
  const notes = String(form.get("notes") ?? "").trim().slice(0, 300) || null;

  if (!product) return { status: "error", message: "That product isn't available. Refresh the page and try again." };
  if (name.length < 2 || name.length > 80) return { status: "error", field: "name", message: "Tell us your name." };
  if (!phone) return { status: "error", field: "phone", message: "That number doesn't look right. Try something like 0412 345 678." };

  let id: number;
  try {
    const db = await getDb();
    const [row] = await db.query<{ id: number }>(
      `INSERT INTO shop_interest (product, name, phone, notes) VALUES ($1, $2, $3, $4) RETURNING id`,
      [product.id, name, phone, notes],
    );
    id = row.id;
  } catch (err) {
    console.error("registerInterest failed", err);
    return { status: "error", message: "Something went wrong on our side. Try again, or DM us on Instagram." };
  }

  // The interest is saved either way; the email is a notification on top.
  try {
    const sent = await sendClubMail({
      subject: `Shop interest: ${product.name} (${product.price}) from ${name}`,
      text: [
        `${name} registered interest in the ${product.name} (${product.price}).`,
        "",
        `Name:   ${name}`,
        `Mobile: ${prettyPhone(phone)}`,
        notes ? `Notes:  ${notes}` : null,
        "",
        "Everyone who registered interest is also listed in the admin dashboard under Shop.",
      ]
        .filter((l) => l !== null)
        .join("\n"),
    });
    if (sent) {
      const db = await getDb();
      await db.query(`UPDATE shop_interest SET emailed = true WHERE id = $1`, [id]);
    }
  } catch (err) {
    console.error("shop interest email failed", err);
  }
  return { status: "ok", name: name.split(" ")[0] };
}
