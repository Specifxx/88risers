/**
 * 88 Moments: a Riser books the camera before a comp, we follow them on the day, and their best moment
 * becomes sumi-e ink artwork. The booking covers the coverage, the artwork and the digital file; printed
 * pieces are add-ons, priced at roughly 1.6–1.8× what one-off production costs. Client-safe.
 */
/** Camera coverage at the comp + your sumi-e artwork + the high-res digital file. Everyone pays this. */
export const MOMENTS_BASE = 49;
export const MOMENT_ITEMS = [
  { id: "framed", name: "Framed A3 print", blurb: "Archival print on textured paper, black frame, 88 Risers plaque", price: 120 },
  { id: "metal", name: "A3 metal print", blurb: "Brushed aluminium plate with stand-off mounts", price: 150 },
  { id: "scroll", name: "Hanging scroll", blurb: "Traditional scroll with wooden rods and hanging cord", price: 120 },
  { id: "shirt", name: "Printed shirt", blurb: "Your own artwork, one-off printed across the back of a black tee", price: 70 },
  { id: "crystal", name: "3D crystal cube", blurb: "Laser-engraved inside a crystal block, on a black base", price: 180 },
] as const;
export type MomentItemId = (typeof MOMENT_ITEMS)[number]["id"];
/** Booking + all five pieces priced one by one. */
export const MOMENTS_ITEMS_SUM = MOMENTS_BASE + MOMENT_ITEMS.reduce((n, i) => n + i.price, 0);
/** The full Risers Moment Package: booking + all five pieces, bundle price. */
export const MOMENTS_FULL_SET = 549;
/** Paid when booking, to hold the camera for you. Non-refundable; it comes off the total. */
export const MOMENTS_DEPOSIT = 30;
export const SHIRT_SIZES = ["S", "M", "L", "XL", "2XL", "3XL"] as const;
export const MOMENT_EVENTS = ["Nationals", "Rhodes Open 2027", "State titles", "Club supermatch", "Club meet / table time", "Other event"] as const;
/** What a booking costs: the booking fee plus any pieces, or the package price when all five are picked. */
export const momentsTotal = (ids: string[]) => {
  const picked = MOMENT_ITEMS.filter((i) => ids.includes(i.id));
  if (picked.length === MOMENT_ITEMS.length) return MOMENTS_FULL_SET;
  return MOMENTS_BASE + picked.reduce((n, i) => n + i.price, 0);
};
