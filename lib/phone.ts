/**
 * Normalise a phone number to E.164. Australian numbers may be typed the
 * usual local way (0412 345 678); anything else must start with +.
 */
export function normalisePhone(raw: string): string | null {
  const s = raw.replace(/[\s\-().]/g, "");
  let digits: string;
  if (/^\+\d{8,15}$/.test(s)) digits = s;
  else if (/^0[2-578]\d{8}$/.test(s)) digits = "+61" + s.slice(1);
  else if (/^61[2-578]\d{8}$/.test(s)) digits = "+" + s;
  else if (/^[2-578]\d{8}$/.test(s)) digits = "+61" + s;
  else return null;
  if (digits.startsWith("+61") && !/^\+61[2-578]\d{8}$/.test(digits)) return null;
  return digits;
}

export function prettyPhone(e164: string) {
  const m = /^\+61(4\d{2})(\d{3})(\d{3})$/.exec(e164);
  if (m) return `0${m[1]} ${m[2]} ${m[3]}`;
  const l = /^\+61([2378])(\d{4})(\d{4})$/.exec(e164);
  if (l) return `(0${l[1]}) ${l[2]} ${l[3]}`;
  return e164;
}
