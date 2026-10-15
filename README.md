# 88 Risers — Arm Wrestling Club

Website for 88 Risers, a social arm wrestling club in Rhodes, NSW. We're looking for the 88th Riser.

- **Landing page** (`/`) — the club, the 88-seat member grid, champion cards, next table time with countdown, leaderboard, founders, registration, Instagram, FAQ.
- **Register** (`/join`) — name, mobile, photo (resized in the browser), optional Instagram. No accounts. Re-registering with the same number updates the entry.
- **Riser Database** (`/pullers`, `/pullers/8`) — every puller has a permanent Riser ID. Profiles show Elo, rating tier, W–L (by arm), titles, an Elo history chart and match history with embedded videos.
- **Events** (`/events`, `/events/<slug>`) — the first-Sunday table time is generated automatically; tournaments and socials are added by admins. Past events show results with videos. `/api/calendar` serves an `.ics` file.
- **Admin** (`/admin/<ADMIN_KEY>`) — a private link, no sign-in.

## Admin dashboard

Open `https://<site>/admin/<ADMIN_KEY>`. Anyone with the link is an admin, so share it only with organisers. To revoke it, change `ADMIN_KEY` in Vercel and redeploy.

| Tab | What you can do |
| --- | --- |
| Registrations | See sign-ups with photo, tap to call or text, copy every number at once or export a CSV for your SMS tool, add private notes, mark as texted, archive, delete. **Add to database** turns a registrant into a puller with the next Riser ID (or one you choose). |
| Pullers | Edit name, nickname, title, bio, weight class, arm, Instagram; upload a headshot and a champion card image; hide from the site; renumber (matches follow). |
| Matches | Record winner/loser, event, arm, round, weight class, score, video link (YouTube, Instagram reel, TikTok, Google Drive or .mp4), title match. Elo updates for both pullers. Editing or deleting a match replays every rating from scratch. |
| Events | Publish tournaments, socials and other events. An event of type *Table time* on a first Sunday replaces that month's auto-generated session, which is how you move, rename or cancel one. |

Registration photos and phone numbers are only visible through the admin link. A registrant's photo becomes public once they're added to the database (it's their profile photo).

## Ratings

Elo, everyone starts at 1000, K = 32. Tiers: Prospect (<950), Riser (950+), Contender (1050+), Challenger (1150+), Elite (1250+), Champion (1350+). Ratings are marked provisional for the first 5 matches. See `lib/elo.ts` to tune.

## Develop

```bash
npm install
npm run dev
```

Open http://localhost:3000 and http://localhost:3000/admin/dev-admin. Without `DATABASE_URL` the app uses PGlite (Postgres in WebAssembly) stored in `./.data/`; delete that folder to reset. The schema is created and the eight founders (#001–#008) are seeded automatically on first run.

## Deploy on Vercel

1. Import this repository as a Vercel project (or connect it to the existing `88-risers` project).
2. **Storage → Create Database → Neon (Postgres)** and connect it to the project. This sets `DATABASE_URL`. (Any Postgres works: Supabase, Railway, etc.)
3. **Settings → Environment Variables**: add `ADMIN_KEY` (long and random, e.g. `openssl rand -base64 24 | tr -d '/+='`) and optionally `NEXT_PUBLIC_SITE_URL`.
4. Deploy. Tables are created on the first request.

Bookmark `https://<your-domain>/admin/<ADMIN_KEY>` on the organisers' phones.

## Stack

Next.js 16 (App Router, server actions), React 19, plain CSS, `postgres` driver. Photos are stored in Postgres, so there's no separate file storage to configure.

Public pages are cached by Vercel and regenerated in the background at most once a minute; every admin change refreshes them immediately. If the database is briefly unavailable (Neon's free tier sleeps when idle), visitors keep seeing the cached pages, and database calls retry automatically.

```
app/(site)/        public pages
app/admin/[key]/   admin dashboard + server actions
app/api/           photos, calendar (.ics), CSV export
components/        UI (Slab = cased-card component with holo tilt)
lib/               db (schema + seed), data queries, Elo, schedule, phone parsing
```
