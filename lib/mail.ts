import "server-only";
import nodemailer from "nodemailer";
import { SITE } from "./site";

/**
 * Club email, sent from the club Gmail account with an app password
 * (Google Account → Security → 2-Step Verification → App passwords).
 * Set GMAIL_USER and GMAIL_APP_PASSWORD in Vercel; without them nothing is
 * sent and callers fall back to what they stored in the database.
 */
export function mailConfigured() {
  return Boolean(process.env.GMAIL_USER && process.env.GMAIL_APP_PASSWORD);
}

export async function sendClubMail(msg: { subject: string; text: string; replyTo?: string }) {
  if (!mailConfigured()) return false;
  const user = process.env.GMAIL_USER!;
  const transport = nodemailer.createTransport({
    service: "gmail",
    auth: { user, pass: process.env.GMAIL_APP_PASSWORD!.replace(/\s+/g, "") },
  });
  await transport.sendMail({
    from: `"${SITE.name} website" <${user}>`,
    to: process.env.MAIL_TO || SITE.email,
    subject: msg.subject,
    text: msg.text,
    replyTo: msg.replyTo,
  });
  return true;
}
