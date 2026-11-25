/**
 * Downscale in the browser so phone photos (often 5–12 MB) upload quickly and take little room
 * in the database. WebP where the browser can encode it (about a third smaller), else JPEG.
 */
export async function shrinkImage(file: File, max = 900): Promise<File> {
  try {
    const bmp = await createImageBitmap(file);
    const scale = Math.min(1, max / Math.max(bmp.width, bmp.height));
    const canvas = document.createElement("canvas");
    canvas.width = Math.round(bmp.width * scale);
    canvas.height = Math.round(bmp.height * scale);
    canvas.getContext("2d")!.drawImage(bmp, 0, 0, canvas.width, canvas.height);
    const encode = (type: string, q: number) => new Promise<Blob | null>((r) => canvas.toBlob(r, type, q));
    let blob = await encode("image/webp", 0.8);
    // Browsers that can't encode WebP silently hand back a (much larger) PNG instead.
    if (!blob || blob.type !== "image/webp") blob = await encode("image/jpeg", 0.82);
    if (!blob) return file;
    if (blob.size >= file.size && scale === 1 && /^image\/(jpeg|webp)$/.test(file.type)) return file;
    const ext = blob.type === "image/webp" ? "webp" : "jpg";
    return new File([blob], `photo.${ext}`, { type: blob.type });
  } catch {
    return file; // e.g. HEIC on browsers that can't decode it — the server will validate
  }
}
