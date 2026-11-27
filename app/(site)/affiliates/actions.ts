"use server";

import { revalidatePath } from "next/cache";
import { joinAffiliates, resendDashboard } from "@/lib/affiliates";

export type JoinState = { status: "idle" } | { status: "error"; message: string } | { status: "ok"; token: string };

export async function joinAffiliate(_prev: JoinState, form: FormData): Promise<JoinState> {
  if (String(form.get("company") ?? "").trim()) return { status: "idle" }; // bots
  if (form.get("agree") !== "on") return { status: "error", message: "Tick to agree to the affiliate terms." };
  try {
    const r = await joinAffiliates({
      name: String(form.get("name") ?? ""),
      code: String(form.get("code") ?? ""),
      email: String(form.get("email") ?? ""),
      phone: String(form.get("phone") ?? ""),
      method: String(form.get("method") ?? "paypal"),
      bankName: String(form.get("bank_name") ?? ""),
      bsb: String(form.get("bsb") ?? ""),
      account: String(form.get("account") ?? ""),
    });
    if ("error" in r) return { status: "error", message: r.error ?? "Something went wrong." };
    revalidatePath("/affiliates");
    return { status: "ok", token: r.affiliate.token };
  } catch (e) {
    console.error("affiliate join failed", e);
    return { status: "error", message: "Something went wrong on our side. Try again, or DM us on Instagram." };
  }
}

export async function resendAffiliateLink(_prev: { sent: boolean }, form: FormData) {
  await resendDashboard(String(form.get("email") ?? ""));
  return { sent: true };
}
