"use server";

import { getDb } from "@/lib/db";
import { normalisePhone } from "@/lib/phone";
import { MOMENT_EVENTS, MOMENT_ITEMS, SHIRT_SIZES, momentsTotal } from "@/lib/momentsConfig";

export type MomentState =
  | { status: "idle" }
  | { status: "error"; message: string; field?: "name" | "phone" | "email" | "event" | "moment" | "items" | "shirt_size" | "delivery" | "consent" }
  | { status: "ok"; name: string; total: number; count: number };

/** Records an 88 Moments order. Payment is arranged afterwards, once the artwork is approved. */
export async function orderMoments(_prev: MomentState, form: FormData): Promise<MomentState> {
  if (String(form.get("company") ?? "").trim()) return { status: "ok", name: "", total: 0, count: 0 };
  const s = (k: string) => String(form.get(k) ?? "").trim();
  const name = s("name").replace(/\s+/g, " ");
  const phone = normalisePhone(s("phone"));
  const email = s("email").toLowerCase().slice(0, 120) || null;
  const instagram = s("instagram").replace(/^@/, "").slice(0, 60) || null;
  const event = s("event");
  const eventOther = s("event_other").slice(0, 120);
  const moment = s("moment").slice(0, 600);
  const valid = new Set<string>(MOMENT_ITEMS.map((i) => i.id));
  const items = [...new Set(form.getAll("items").map(String))].filter((i) => valid.has(i));
  const shirt = items.includes("shirt") ? s("shirt_size") : "";
  const delivery = s("delivery");
  const notes = s("notes").slice(0, 400) || null;

  if (name.length < 2 || name.length > 80) return { status: "error", field: "name", message: "Tell us your full name." };
  if (!phone) return { status: "error", field: "phone", message: "That number doesn't look right. Try something like 0412 345 678." };
  if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return { status: "error", field: "email", message: "That email doesn't look right." };
  if (!(MOMENT_EVENTS as readonly string[]).includes(event)) return { status: "error", field: "event", message: "Pick the event." };
  if (event === "Other event" && eventOther.length < 2) return { status: "error", field: "event", message: "Tell us which event." };
  if (moment.length < 5) return { status: "error", field: "moment", message: "Tell us which match or moment (who you pulled, roughly when)." };
  if (!items.length) return { status: "error", field: "items", message: "Pick at least one piece." };
  if (items.includes("shirt") && !(SHIRT_SIZES as readonly string[]).includes(shirt)) return { status: "error", field: "shirt_size", message: "Pick a shirt size." };
  if (delivery !== "pickup" && delivery !== "post") return { status: "error", field: "delivery", message: "Pick up at a meet, or post?" };
  if (form.get("consent") !== "on")
    return { status: "error", field: "consent", message: "Tick to confirm you're 18+ (or a parent is ordering) and happy for us to use your photos." };

  const total = momentsTotal(items);
  try {
    const db = await getDb();
    await db.query(
      `INSERT INTO moment_orders (name, phone, email, instagram, event, moment, items, shirt_size, total, delivery, notes)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
      [name, phone, email, instagram, event === "Other event" ? `Other: ${eventOther}` : event, moment, items, shirt || null, total, delivery, notes],
    );
    return { status: "ok", name: name.split(" ")[0], total, count: items.length };
  } catch (err) {
    console.error("moments order failed", err);
    return { status: "error", message: "Something went wrong on our side. Try again, or DM us on Instagram." };
  }
}
