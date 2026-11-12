import "server-only";
import { getDb } from "./db";

import { OPEN, type OpenArms } from "./rhodesOpenConfig";

export { ARMS_LABEL, OPEN, classLabel, type OpenArms, type OpenClass } from "./rhodesOpenConfig";

export type OpenEntry = {
  id: number;
  name: string;
  phone: string;
  email: string | null;
  instagram: string | null;
  riser_id: number | null;
  arms: OpenArms;
  weight_class: string;
  notes: string | null;
  created_at: Date;
};

export async function openEntries(): Promise<OpenEntry[]> {
  const db = await getDb();
  return db.query<OpenEntry>(
    `SELECT id, name, phone, email, instagram, riser_id, arms, weight_class, notes, created_at
     FROM comp_entries WHERE comp = $1 ORDER BY created_at`,
    [OPEN.slug],
  );
}

/** How many have entered each bracket (a both-arms entry counts in right and left). */
export function bracketCounts(entries: Pick<OpenEntry, "arms" | "weight_class">[]) {
  return OPEN.classes.map((c) => ({
    cls: c,
    right: entries.filter((e) => e.weight_class === c && e.arms !== "left").length,
    left: entries.filter((e) => e.weight_class === c && e.arms !== "right").length,
  }));
}

export async function openEntryCount(): Promise<number> {
  const db = await getDb();
  const [r] = await db.query<{ n: number }>(`SELECT count(*)::int AS n FROM comp_entries WHERE comp = $1`, [OPEN.slug]);
  return r?.n ?? 0;
}
