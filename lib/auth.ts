import "server-only";
import { createHash, randomBytes, scrypt as scryptCb, timingSafeEqual } from "node:crypto";
import { promisify } from "node:util";
import { cookies } from "next/headers";
import { getDb } from "./db";

const scrypt = promisify(scryptCb) as (pw: string, salt: Buffer, len: number) => Promise<Buffer>;

const COOKIE = "88r_session";
const SESSION_DAYS = 60;

export interface Account {
  id: number;
  handle: string;
  display_name: string;
  coins: number;
}

/** "scrypt$<salt>$<hash>", both base64url. */
export async function hashPassword(pw: string) {
  const salt = randomBytes(16);
  const hash = await scrypt(pw, salt, 32);
  return `scrypt$${salt.toString("base64url")}$${hash.toString("base64url")}`;
}

export async function verifyPassword(pw: string, stored: string) {
  const [kind, salt, hash] = stored.split("$");
  if (kind !== "scrypt" || !salt || !hash) return false;
  const expected = Buffer.from(hash, "base64url");
  const actual = await scrypt(pw, Buffer.from(salt, "base64url"), expected.length);
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

const sha = (s: string) => createHash("sha256").update(s).digest("hex");

/** Starts a session for the account and sets the cookie. Call from a Server Function only. */
export async function startSession(accountId: number) {
  const token = randomBytes(32).toString("base64url");
  const expires = new Date(Date.now() + SESSION_DAYS * 864e5);
  const db = await getDb();
  await db.query(`INSERT INTO sessions (token_hash, account_id, expires_at) VALUES ($1, $2, $3)`, [sha(token), accountId, expires]);
  (await cookies()).set(COOKIE, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    expires,
  });
}

export async function endSession() {
  const store = await cookies();
  const token = store.get(COOKIE)?.value;
  if (token) {
    const db = await getDb();
    await db.query(`DELETE FROM sessions WHERE token_hash = $1`, [sha(token)]);
  }
  store.delete(COOKIE);
}

/** The signed-in account, or null. Reading cookies makes the calling page dynamic. */
export async function currentAccount(): Promise<Account | null> {
  const token = (await cookies()).get(COOKIE)?.value;
  if (!token) return null;
  const db = await getDb();
  const [row] = await db.query<Account>(
    `SELECT a.id, a.handle, a.display_name,
            coalesce((SELECT sum(amount) FROM coin_tx t WHERE t.account_id = a.id), 0)::int AS coins
     FROM sessions s JOIN accounts a ON a.id = s.account_id
     WHERE s.token_hash = $1 AND s.expires_at > now()`,
    [sha(token)],
  );
  return row ?? null;
}

/** Usernames: 3–20 lowercase letters, numbers or underscores. */
export function cleanHandle(raw: string) {
  const h = raw.trim().replace(/^@/, "").toLowerCase();
  return /^[a-z0-9_]{3,20}$/.test(h) ? h : null;
}
