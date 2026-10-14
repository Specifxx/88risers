/* eslint-disable @next/next/no-img-element */
export function Avatar({ src, name, size = 38 }: { src: string | null; name: string; size?: number }) {
  if (src) return <img className="avatar" src={src} alt="" width={size} height={size} style={{ width: size, height: size }} loading="lazy" />;
  return (
    <span className="avatar avatar-fallback" style={{ width: size, height: size }} aria-hidden>
      {name.trim().charAt(0).toUpperCase()}
    </span>
  );
}
