/** 88 Moments: event photos turned into sumi-e ink artwork, on prints and keepsakes. Client-safe. */
export const MOMENT_ITEMS = [
  { id: "framed", name: "Framed A3 print", blurb: "Archival print on textured paper, black frame, 88 Risers plaque", price: 60 },
  { id: "metal", name: "Metal print", blurb: "Brushed aluminium plate with stand-off mounts", price: 80 },
  { id: "scroll", name: "Hanging scroll", blurb: "Traditional scroll with wooden rods and hanging cord", price: 60 },
  { id: "shirt", name: "Printed shirt", blurb: "Your artwork across the back of a black tee", price: 30 },
  { id: "crystal", name: "Crystal cube", blurb: "Laser-engraved inside a crystal block, on a black base", price: 40 },
] as const;
export type MomentItemId = (typeof MOMENT_ITEMS)[number]["id"];
export const MOMENTS_FULL_SET = MOMENT_ITEMS.reduce((n, i) => n + i.price, 0); // $270
export const SHIRT_SIZES = ["S", "M", "L", "XL", "2XL", "3XL"] as const;
export const MOMENT_EVENTS = ["Nationals", "Rhodes Open 2027", "State titles", "Club supermatch", "Club meet / table time", "Other event"] as const;
export const momentsTotal = (ids: string[]) => MOMENT_ITEMS.filter((i) => ids.includes(i.id)).reduce((n, i) => n + i.price, 0);
