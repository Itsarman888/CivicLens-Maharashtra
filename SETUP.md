# CivicLens Maharashtra — shared community civic reports

CivicLens helps residents publish local civic issues, explore them on an interactive Maharashtra map, support reports, post comments, and ask an AI helper for general civic guidance. This version uses Supabase for shared reports/authentication/storage and a Vercel serverless function for the AI helper.

## What's implemented
- Shared report feed backed by Supabase Postgres (not browser localStorage). Reports can be read across devices.
- Guest-first reporting, community support votes, and comments; residents do not need to create accounts after the guest migration is applied.
- Interactive OpenStreetMap/Leaflet map with report markers and a map picker for report coordinates.
- Image uploads to Supabase Storage (JPEG/PNG/WebP, max 5 MB).
- AI helper API endpoint at `/api/helper`; AI key stays on the server in Vercel environment variables.
- Row Level Security policies for report writes, votes, comments, and storage.

## Required setup before deployment
The ZIP is code-complete but not connected to your Supabase project or OpenAI API account yet. Do these setup steps to enable shared data and AI.

1. Use your existing Supabase project. Do not recreate tables.
2. Since your schema and base policies already exist, do not rerun `supabase/schema.sql`. Back up first, then run `supabase/guest-migration.sql` once after reviewing it.
3. Open **Project Settings → API**. Copy the Project URL and the **publishable/anon key** (not the service-role key). Put them into `public/config.js` as `supabaseUrl` and `supabaseAnonKey`. These values are browser-visible; Row Level Security is essential.
4. In Supabase **Authentication → URL Configuration**, add your deployed Vercel URL to Site URL / Redirect URLs after first deployment. For local testing, add `http://localhost:3000/**`. Depending on your auth settings, sign-up confirmation emails may need to be confirmed before sign-in.
5. Create an OpenAI API key in your own account. In Vercel Project → Settings → Environment Variables add `OPENAI_API_KEY`. Optionally add `OPENAI_MODEL` = `gpt-4o-mini`. Never put the AI key in `public/config.js` or commit it to GitHub. API usage may cost money.
6. Deploy the extracted project folder to Vercel. Framework preset: **Other**. Root directory: project root. Build command: leave blank. Output directory: `public`. Install command: `npm install`. Add the environment variables and deploy. Direct CLI deployment is possible with the Vercel CLI; GitHub is optional.
7. After deployment, open the app on two different devices/browsers, create/confirm separate accounts, submit a report, then refresh the second device to verify the report appears.

## Local development
Requires Node.js and a Vercel account/CLI. From this directory run:

```bash
npm install
npx vercel dev
```

Configure `public/config.js` and add `OPENAI_API_KEY` to a local `.env` file (do not commit it).

## Important behavior / limitations
- Shared reports are only enabled after Supabase setup. No fake sample reports are inserted into your database.
- The report map uses coordinates selected by the reporter. Users should place a nearby public landmark rather than their home. The city selector is used as report metadata, not as an automatic geocoder.
- The map uses OpenStreetMap public tiles; follow their tile usage policy for production-scale traffic.
- AI responses are general information, not official municipal decisions or emergency dispatch. For immediate danger in India, call 112; do not approach electrical, flood, or structural hazards.
- The moderator panel is not a role-management UI. RLS blocks unauthorized status changes; an administrator must manually assign trusted moderator roles using the SQL editor. Do not give the public an admin role.
- For a public production launch, add rate limiting/spam controls, moderation/reporting workflows, backups, and privacy/retention policies.

## GitHub suggested metadata
- Repository: `civiclens-maharashtra`
- Description: `Shared civic issue reporting for Maharashtra with an interactive map, community support, persistent image uploads, and an AI civic helper.`
- Topics: `civic-tech`, `maharashtra`, `supabase`, `vercel`, `leaflet`, `openstreetmap`, `community`

Independent community project; not an official government service.


## Switch to guest mode (no resident account)
1. In Supabase, make a database backup first.
2. Open SQL Editor and run `supabase/guest-migration.sql` ONCE. Do not rerun the original `schema.sql`; it creates policies that may already exist.
3. Keep `public/config.js` filled with your Supabase project URL and publishable/anon key only. Never put a service-role key in browser code.
4. Deploy this folder to Vercel.
5. Test in a private/incognito window: browse reports, submit a test report, support it, add a comment, and refresh.

Guest mode means there is no identity verification. Browser IDs can be cleared or spoofed, so do not treat votes as verified residents. For a public production launch, add server-side rate limits and CAPTCHA, image moderation, and verified moderator tooling. The public report feed and guest submissions depend on Supabase Row Level Security policies.
