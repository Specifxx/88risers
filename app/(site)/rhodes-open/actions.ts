"use server";

import { revalidatePath } from "next/cache";
import { getDb } from "@/lib/db";
import { normalisePhone } from "@/lib/phone";
import { OPEN, type OpenArms } from "@/lib/rhodesOpenConfig";

export type OpenState =
  | { status: "idle" }
  | { status: "error"; message: string; field?: "name" | "phone" | "email" | "arms" | "weight_class" | "riser_id" | "adult" }
  | { status: "ok"; name: string; updated: boolean; arms: OpenArms; weightClass: string };

/** Registers (or updates) an entry for the Rhodes Open. No payment is taken. */
export async function enterOpen(_prev: OpenState, form: FormData): Promise<OpenState> {
  if (String(form.get("company") ?? "").trim()) return { status: "ok", name: "", updated: false, arms: "right", weightClass: "" };
  const s = (k: string) => String(form.get(k) ?? "").trim();
  const name = s("name").replace(/\s+/g, " ");
  const phone = normalisePhone(s("phone"));
  const email = s("email").toLowerCase().slice(0, 120) || null;
  const instagram = s("instagram").replace(/^@/, "").slice(0, 60) || null;
  const riserRaw = s("riser_id").replace(/^#/, "");
  const riser = riserRaw ? Number(riserRaw) : null;
  const arms = s("arms") as OpenArms;
  const weightClass = s("weight_class");
  const notes = s("notes").slice(0, 400) || null;

  if (name.length < 2 || name.length > 80) return { status: "error", field: "name", message: "Tell us your full name." };
  if (!phone) return { status: "error", field: "phone", message: "That number doesn't look right. Try something like 0412 345 678." };
  if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return { status: "error", field: "email", message: "That email doesn't look right." };
  if (riser !== null && (!Number.isInteger(riser) || riser < 1 || riser > 9999))
    return { status: "error", field: "riser_id", message: "Riser IDs are numbers like 017. Leave it blank if you don't have one." };
  if (!["right", "left", "both"].includes(arms)) return { status: "error", field: "arms", message: "Pick right arm, left arm or both." };
  if (!(OPEN.classes as readonly string[]).includes(weightClass)) return { status: "error", field: "weight_class", message: "Pick your weight class." };
  if (form.get("adult") !== "on")
    return { status: "error", field: "adult", message: "Tick to confirm you're 18 or over. Under 18? DM us on Instagram first." };

  try {
    const db = await getDb();
    const [row] = await db.query<{ inserted: boolean }>(
      `INSERT INTO comp_entries (comp, name, phone, email, instagram, riser_id, arms, weight_class, notes)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       ON CONFLICT (comp, phone) DO UPDATE SET
         name = EXCLUDED.name, email = coalesce(EXCLUDED.email, comp_entries.email),
         instagram = coalesce(EXCLUDED.instagram, comp_entries.instagram),
         riser_id = coalesce(EXCLUDED.riser_id, comp_entries.riser_id),
         arms = EXCLUDED.arms, weight_class = EXCLUDED.weight_class,
         notes = coalesce(EXCLUDED.notes, comp_entries.notes), updated_at = now()
       RETURNING (xmax = 0) AS inserted`,
      [OPEN.slug, name, phone, email, instagram, riser, arms, weightClass, notes],
    );
    revalidatePath("/rhodes-open");
    return { status: "ok", name: name.split(" ")[0], updated: !row.inserted, arms, weightClass };
  } catch (err) {
    console.error("rhodes open entry failed", err);
    return { status: "error", message: "Something went wrong on our side. Try again, or DM us on Instagram." };
  }
}
