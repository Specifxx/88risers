import "server-only";
import { createHash, randomBytes, scrypt as scryptCb, timingSafeEqual } from "node:crypto";
import { promisify } from "node:util";
import { cookies } from "next/headers";
import { getDb } from "./db";

const scrypt = promisify(scryptCb) as (pw: string, salt: Buffer, len: number) => Promise<Buffer>;

const COOKIE = "88r_session";
/** A readable "logged in" hint (no secret in it) so static pages can label the account button. */
export const HINT_COOKIE = "88r_in";
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

const RESET_HOURS = 48;

/** Makes a one-time reset link token for an account (older unused links stop working). */
export async function createResetToken(accountId: number) {
  const token = randomBytes(24).toString("base64url");
  const db = await getDb();
  await db.query(`DELETE FROM password_resets WHERE account_id = $1 OR expires_at < now()`, [accountId]);
  await db.query(`INSERT INTO password_resets (token_hash, account_id, expires_at) VALUES ($1, $2, now() + make_interval(hours => $3))`, [
    sha(token),
    accountId,
    RESET_HOURS,
  ]);
  return token;
}

/** The account a reset link belongs to, if the link is still valid. */
export async function resetTarget(token: string) {
  if (!token) return null;
  const db = await getDb();
  const [r] = await db.query<{ id: number; handle: string; display_name: string }>(
    `SELECT a.id, a.handle, a.display_name FROM password_resets p JOIN accounts a ON a.id = p.account_id
     WHERE p.token_hash = $1 AND p.used_at IS NULL AND p.expires_at > now()`,
    [sha(token)],
  );
  return r ?? null;
}

/** Uses up a reset link: sets the new password, ends all old sessions. Returns the account id. */
export async function consumeReset(token: string, password: string) {
  const db = await getDb();
  const hash = await hashPassword(password);
  return db.transaction(async (tx) => {
    const [r] = await tx.query<{ account_id: number }>(
      `UPDATE password_resets SET used_at = now() WHERE token_hash = $1 AND used_at IS NULL AND expires_at > now() RETURNING account_id`,
      [sha(token)],
    );
    if (!r) return null;
    await tx.query(`UPDATE accounts SET pass_hash = $2 WHERE id = $1`, [r.account_id, hash]);
    await tx.query(`DELETE FROM sessions WHERE account_id = $1`, [r.account_id]);
    await tx.query(`DELETE FROM login_attempts WHERE handle = (SELECT handle FROM accounts WHERE id = $1)`, [r.account_id]);
    return r.account_id;
  });
}

/** Changes a logged-in member's password after checking the current one. Other devices are logged out. */
export async function changePassword(accountId: number, current: string, next: string) {
  const db = await getDb();
  const [a] = await db.query<{ pass_hash: string }>(`SELECT pass_hash FROM accounts WHERE id = $1`, [accountId]);
  if (!a || !(await verifyPassword(current, a.pass_hash))) return false;
  const token = (await cookies()).get(COOKIE)?.value ?? "";
  await db.query(`UPDATE accounts SET pass_hash = $2 WHERE id = $1`, [accountId, await hashPassword(next)]);
  await db.query(`DELETE FROM sessions WHERE account_id = $1 AND token_hash <> $2`, [accountId, sha(token)]);
  return true;
}

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
  (await cookies()).set(HINT_COOKIE, "1", { sameSite: "lax", path: "/", expires, secure: process.env.NODE_ENV === "production" });
}

export async function endSession() {
  const store = await cookies();
  const token = store.get(COOKIE)?.value;
  if (token) {
    const db = await getDb();
    await db.query(`DELETE FROM sessions WHERE token_hash = $1`, [sha(token)]);
  }
  store.delete(COOKIE);
  store.delete(HINT_COOKIE);
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
