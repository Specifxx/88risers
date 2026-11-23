/**
 * 88 Moments: a Riser books the camera before a comp, we follow them on the day, and their best moment
 * becomes sumi-e ink artwork on prints and keepsakes. Client-safe (no database imports).
 */
export const MOMENT_ITEMS = [
  { id: "framed", name: "Framed A3 print", blurb: "Archival print on textured paper, black frame, 88 Risers plaque", price: 60 },
  { id: "metal", name: "Metal print", blurb: "Brushed aluminium plate with stand-off mounts", price: 80 },
  { id: "scroll", name: "Hanging scroll", blurb: "Traditional scroll with wooden rods and hanging cord", price: 60 },
  { id: "shirt", name: "Printed shirt", blurb: "Your own artwork, one-off printed across the back of a black tee", price: 60 },
  { id: "crystal", name: "Crystal cube", blurb: "Laser-engraved inside a crystal block, on a black base", price: 40 },
] as const;
export type MomentItemId = (typeof MOMENT_ITEMS)[number]["id"];
/** All five pieces priced one by one. */
export const MOMENTS_ITEMS_SUM = MOMENT_ITEMS.reduce((n, i) => n + i.price, 0);
/** The full Risers Moment Package: all five pieces, bundle price. */
export const MOMENTS_FULL_SET = 270;
export const SHIRT_SIZES = ["S", "M", "L", "XL", "2XL", "3XL"] as const;
export const MOMENT_EVENTS = ["Nationals", "Rhodes Open 2027", "State titles", "Club supermatch", "Club meet / table time", "Other event"] as const;
/** What a booking costs: the package price when all five pieces are picked, otherwise piece by piece. */
export const momentsTotal = (ids: string[]) => {
  const picked = MOMENT_ITEMS.filter((i) => ids.includes(i.id));
  if (picked.length === MOMENT_ITEMS.length) return MOMENTS_FULL_SET;
  return picked.reduce((n, i) => n + i.price, 0);
};
