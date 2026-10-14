import { SiteFooter } from "@/components/SiteFooter";
import { SiteHeader } from "@/components/SiteHeader";
import SiteNotFound from "./(site)/not-found";

export default function NotFound() {
  return (
    <>
      <SiteHeader />
      <main id="main">
        <SiteNotFound />
      </main>
      <SiteFooter />
    </>
  );
}
