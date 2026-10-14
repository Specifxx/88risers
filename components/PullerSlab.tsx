import type { Puller } from "@/lib/data";
import { formatId } from "@/lib/site";
import { CardFace } from "./CardFace";
import { Slab } from "./Slab";

export function PullerSlab({ p, link = true, priority }: { p: Puller; link?: boolean; priority?: boolean }) {
  return (
    <Slab
      href={link ? `/pullers/${p.id}` : undefined}
      label={{
        name: p.name,
        sub: p.is_founder ? "Founding member" : p.title || p.weight_class || "88 Risers puller",
        grade: formatId(p.id).slice(1),
      }}
    >
      <CardFace name={p.name} id={p.id} title={p.title} photo={p.photo_url} card={p.card_url} priority={priority} />
    </Slab>
  );
}
