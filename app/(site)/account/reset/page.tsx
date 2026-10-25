import type { Metadata } from "next";
import Link from "next/link";
import { ResetPasswordForm } from "@/components/PasswordForms";
import { resetTarget } from "@/lib/auth";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Reset your password",
  robots: { index: false },
  referrer: "no-referrer",
};

export default async function ResetPage({ searchParams }: PageProps<"/account/reset">) {
  const sp = await searchParams;
  const token = typeof sp.t === "string" ? sp.t : "";
  const who = await resetTarget(token);
  return (
    <>
      <section className="page-hero">
        <div className="wrap">
          <p className="crumbs">
            <Link href="/">Home</Link> / <Link href="/account">Account</Link> / Reset password
          </p>
          <h1 className="display">
            {who ? (
              <>
                Hey {who.display_name.split(" ")[0]}<span className="gold-text">.</span>
              </>
            ) : (
              <>
                Link <span className="gold-text">expired.</span>
              </>
            )}
          </h1>
          <p className="lede">
            {who
              ? "Choose a new password for your 88 Risers account. Your coins, Chalk and lions are all still there."
              : "This reset link has expired or was already used. Message us on Instagram and an organiser will send you a new one."}
          </p>
        </div>
      </section>
      <section className="section" style={{ paddingTop: 32 }}>
        <div className="wrap" style={{ maxWidth: 520 }}>
          {who ? (
            <ResetPasswordForm token={token} handle={who.handle} />
          ) : (
            <Link className="btn btn-primary" href="/account?mode=login">
              Back to log in
            </Link>
          )}
        </div>
      </section>
    </>
  );
}
