import "server-only";
import { timingSafeEqual } from "node:crypto";

/**
 * The admin dashboard has no login: it lives at /admin/<ADMIN_KEY>. Anyone with
 * the link is an admin, so keep the key long and random and share it privately.
 * Rotate it by changing the ADMIN_KEY environment variable and redeploying.
 */
export function adminKey(): string | null {
  const key = process.env.ADMIN_KEY?.trim();
  if (key) return key;
  return process.env.NODE_ENV === "production" ? null : "dev-admin";
}

export function isAdminKey(candidate: unknown): boolean {
  const key = adminKey();
  if (!key || typeof candidate !== "string") return false;
  const a = Buffer.from(candidate);
  const b = Buffer.from(key);
  return a.length === b.length && timingSafeEqual(a, b);
}

export function assertAdmin(candidate: unknown) {
  if (!isAdminKey(candidate)) throw new Error("Not authorised");
}
