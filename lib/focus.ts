/**
 * A photo can carry how it's cropped, as a fragment on the URL: "/api/photos/abc#focus=4,38" is the
 * CSS object-position (4% across, 38% down) for cards and avatars, e.g. to keep the right person in
 * frame in a group photo. The fragment never reaches the server, so the image itself is unchanged.
 */
export function photoPos(url: string | null | undefined): string | undefined {
  const m = url ? /#focus=(\d{1,3}(?:\.\d+)?),(\d{1,3}(?:\.\d+)?)$/.exec(url) : null;
  return m ? `${Math.min(100, +m[1])}% ${Math.min(100, +m[2])}%` : undefined;
}
