import "server-only";
import { getDb } from "./db";

/** Organisers' to-do list, shown at the top of admin HQ. Kept as one JSON value in meta. */
export type Todo = { id: string; text: string; done: boolean; at: number };

const KEY = "admin_todos";

export async function getTodos(): Promise<Todo[]> {
  const db = await getDb();
  const [r] = await db.query<{ value: string }>(`SELECT value FROM meta WHERE key = $1`, [KEY]);
  try {
    const list = r?.value ? (JSON.parse(r.value) as Todo[]) : [];
    return Array.isArray(list) ? list : [];
  } catch {
    return [];
  }
}

export async function saveTodos(list: Todo[]) {
  const db = await getDb();
  await db.query(`INSERT INTO meta (key, value) VALUES ($1, $2) ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value`, [
    KEY,
    JSON.stringify(list.slice(0, 100)),
  ]);
}

export const newTodo = (text: string): Todo => ({
  id: Math.random().toString(36).slice(2, 10),
  text: text.trim().slice(0, 300),
  done: false,
  at: Date.now(),
});
