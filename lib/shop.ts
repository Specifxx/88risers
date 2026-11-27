/** Shop products. Items with `buy` can be ordered and paid for; the rest take registrations of interest. Client-safe. */
export interface Product {
  id: string;
  name: string;
  kind: string;
  price: string;
  blurb: string;
  details: string[];
  badge?: string;
  /** Card image; leave out for "artwork coming" placeholder. */
  image?: { src: string; w: number; h: number; bg?: string };
  /** Full concept sheet shown in the viewer. */
  sheet?: { src: string; w: number; h: number };
  /** On sale: price in AUD, and whether the buyer adds a name, nickname and Riser no. Otherwise "register interest". */
  buy?: { price: number; personalise: boolean };
}

export const SIZES = ["S", "M", "L", "XL", "2XL", "3XL"] as const;
export const SLEEVES = ["Raglan", "Flat"] as const;

/** One cart line, as the buyer chose it. */
export type CartLine = {
  product: string;
  size: string;
  sleeve: string;
  qty: number;
  name?: string;
  nickname?: string;
  riserNo?: string;
};

/**
 * Australia Post prepaid Parcel Post satchels (from 1 July 2026, any address in Australia, up to
 * 5 kg), posted from Doonside. Chosen by how many items are in the order.
 */
export const SATCHELS = [
  { name: "small satchel", upTo: 1, price: 12.05 },
  { name: "medium satchel", upTo: 3, price: 16.4 },
  { name: "large satchel", upTo: 8, price: 20.7 },
] as const;

export function shippingFor(items: number): { label: string; price: number } {
  if (items <= 0) return { label: "", price: 0 };
  const fit = SATCHELS.find((s) => items <= s.upTo);
  if (fit) return { label: `Australia Post ${fit.name}`, price: fit.price };
  const large = SATCHELS[SATCHELS.length - 1];
  const n = Math.ceil(items / large.upTo);
  return { label: `${n} x Australia Post large satchels`, price: Math.round(n * large.price * 100) / 100 };
}

export const money = (n: number) => `$${n.toFixed(2).replace(/\.00$/, "")}`;

export function lineLabel(l: CartLine) {
  const p = PRODUCTS.find((x) => x.id === l.product);
  const bits = [l.size, `${l.sleeve} sleeve`];
  if (p?.buy?.personalise) bits.push([l.name, l.nickname ? `"${l.nickname}"` : "", l.riserNo ? `#${l.riserNo}` : ""].filter(Boolean).join(" "));
  return `${p?.name ?? l.product} (${bits.filter(Boolean).join(", ")})`;
}

export const PRODUCTS: Product[] = [
  {
    id: "tee",
    name: "Club Compression Tee",
    kind: "Apparel",
    price: "$52",
    blurb: "Black sublimated compression tee with gold piping, red brush accents and the red-ring crest on the chest.",
    details: ["Raglan or flat sleeve", "Lightweight, breathable compression fabric", "Sizes S – 3XL"],
    image: { src: "/shop/tee.jpg", w: 1100, h: 715, bg: "#fff" },
    sheet: { src: "/shop/tee-sheet.jpg", w: 1519, h: 927 },
    buy: { price: 52, personalise: false },
  },
  {
    id: "jersey",
    name: "Competition Jersey",
    kind: "Apparel",
    price: "$71",
    badge: "Customised",
    blurb: "The tournament kit. Black with red and gold strikes, the 88 crest and a guardian lion on the front, your name and Riser number over a dragon on the back.",
    details: ["Raglan or flat sleeve", "Your name, nickname and Riser no.", "Performance fabric: breathable, quick-dry, 4-way stretch", "Made to order · sizes S – 3XL"],
    image: { src: "/shop/jersey-v2.webp", w: 1199, h: 700, bg: "#0e0d0c" },
    sheet: { src: "/shop/jersey-v2-sheet.webp", w: 1199, h: 1312 },
    buy: { price: 71, personalise: true },
  },
  {
    id: "handle",
    name: "Arm Wrestling Handle",
    kind: "Training",
    price: "$59.95",
    blurb: "Red aluminium three-finger handle with the textured 88 grip and a heavy-duty embroidered strap. Stronger grips, higher Risers.",
    details: ["Ergonomic contour for cable and band work", "Anodised aluminium alloy end caps", "Steel D-ring attachment"],
    image: { src: "/shop/handle.jpg", w: 678, h: 650, bg: "#0e0d0c" },
    sheet: { src: "/shop/handle-sheet.jpg", w: 1536, h: 1024 },
  },
];

export const productById = (id: string) => PRODUCTS.find((p) => p.id === id) ?? null;
