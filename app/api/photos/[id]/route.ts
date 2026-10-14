import { getPhoto } from "@/lib/data";
import { isAdminKey } from "@/lib/admin";

export async function GET(req: Request, ctx: RouteContext<"/api/photos/[id]">) {
  const { id } = await ctx.params;
  const photo = await getPhoto(id);
  if (!photo) return new Response("Not found", { status: 404 });

  // Registration photos are private: only viewable through the admin link.
  const key = new URL(req.url).searchParams.get("k");
  if (!photo.is_public && !isAdminKey(key)) return new Response("Not found", { status: 404 });

  return new Response(Buffer.from(photo.data), {
    headers: {
      "Content-Type": photo.mime,
      "Cache-Control": photo.is_public ? "public, max-age=31536000, immutable" : "private, no-store",
      "X-Content-Type-Options": "nosniff",
    },
  });
}
