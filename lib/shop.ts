/** Concept shop products. Shared by the shop page and the register-interest action. */
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
}

export const PRODUCTS: Product[] = [
  {
    id: "tee",
    name: "Club Tee",
    kind: "Apparel",
    price: "$64.95",
    blurb: "Black sublimated raglan with gold piping, red brush accents and the red-ring crest on the chest.",
    details: ["88 mark on the left sleeve, Supp Station on the right", "Lightweight, breathable training fabric", "Sizes S – 3XL"],
    image: { src: "/shop/tee.jpg", w: 1100, h: 715, bg: "#fff" },
    sheet: { src: "/shop/tee-sheet.jpg", w: 1519, h: 927 },
  },
  {
    id: "jersey",
    name: "Competition Jersey",
    kind: "Apparel",
    price: "$88.88",
    badge: "Customised",
    blurb: "The tournament kit. Your name and number across the back, dragons on the lower back and 上腕相撲 down the spine.",
    details: ["Name and number of your choice (your Riser ID looks good)", "Premium sublimated competition fabric, raglan fit", "Made to order · sizes S – 3XL"],
    image: { src: "/shop/jersey.jpg", w: 892, h: 598, bg: "#141210" },
    sheet: { src: "/shop/jersey-sheet.jpg", w: 1536, h: 1024 },
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
  {
    id: "belt",
    name: "Riser Belt",
    kind: "Apparel",
    price: "$44.95",
    blurb: "Heavy cotton martial-arts style belt with RISERS embroidered in gold and your Riser ID on the tail.",
    details: ["Black with gold thread", "Embroidered Riser ID", "Sizes 2 – 6"],
  },
  {
    id: "bottle",
    name: "Shaker Bottle",
    kind: "Training",
    price: "$29.95",
    blurb: "Matte black 700 ml shaker with the gold crest. For the energy drinks we don't hand out free.",
    details: ["Leak-proof flip cap", "Mixing ball included", "BPA free"],
  },
  {
    id: "patch",
    name: "Woven Patch",
    kind: "Accessories",
    price: "$14.95",
    blurb: "Gold-on-black RISERS woven patch with the cloud linework and 八十八 seal. Sew it on your bag or jacket.",
    details: ["Merrowed edge", "Iron-on backing", "10 × 4 cm"],
    image: { src: "/gallery/patch.jpg", w: 494, h: 189, bg: "#0e0d0c" },
  },
];

export const productById = (id: string) => PRODUCTS.find((p) => p.id === id) ?? null;
