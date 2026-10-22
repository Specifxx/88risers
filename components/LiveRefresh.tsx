"use client";

import { useRouter } from "next/navigation";
import { useEffect } from "react";

/** Re-fetches the server data every few seconds while the tab is visible (live odds). */
export function LiveRefresh({ seconds }: { seconds: number }) {
  const router = useRouter();
  useEffect(() => {
    const t = setInterval(() => {
      if (document.visibilityState === "visible") router.refresh();
    }, seconds * 1000);
    return () => clearInterval(t);
  }, [router, seconds]);
  return null;
}
