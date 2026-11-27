import "server-only";
import { getDb } from "./db";

/** Organisers' to-do list, shown at the top of admin HQ. Kept as one JSON value in meta. */
export type Todo = { id: string; text: string; done: boolean; at: number };

const KEY = "admin_todos";
/** Ids of removed to-dos, kept separately so an import from an older database can't bring them back. */
const REMOVED = "admin_todos_removed";

async function readJson<T>(key: string, fallback: T): Promise<T> {
  const db = await getDb();
  const [r] = await db.query<{ value: string }>(`SELECT value FROM meta WHERE key = $1`, [key]);
  try {
    return r?.value ? (JSON.parse(r.value) as T) : fallback;
  } catch {
    return fallback;
  }
}

export async function getTodos(): Promise<Todo[]> {
  const [list, removed] = await Promise.all([readJson<Todo[]>(KEY, []), readJson<string[]>(REMOVED, [])]);
  const gone = new Set(Array.isArray(removed) ? removed : []);
  return (Array.isArray(list) ? list : []).filter((t) => !gone.has(t.id));
}

/** Removes a to-do for good. */
export async function removeTodo(id: string) {
  const removed = await readJson<string[]>(REMOVED, []);
  const db = await getDb();
  await db.query(`INSERT INTO meta (key, value) VALUES ($1, $2) ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value`, [
    REMOVED,
    JSON.stringify([...new Set([...(Array.isArray(removed) ? removed : []), id])].slice(-500)),
  ]);
  await saveTodos((await getTodos()).filter((t) => t.id !== id));
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
