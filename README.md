# CivicLens Maharashtra — shared community civic reports

CivicLens helps residents publish local civic issues, explore them on an interactive Maharashtra map, support reports, post comments, and ask an AI helper for general civic guidance. This version uses Supabase for shared reports/authentication/storage and a Vercel serverless function for the AI helper.

## What's implemented
- Shared report feed backed by Supabase Postgres (not browser localStorage). Reports can be read across devices.
- Email/password sign-up and sign-in for report creation, votes, and comments.
- Interactive OpenStreetMap/Leaflet map with report markers and a map picker for report coordinates.
- Image uploads to Supabase Storage (JPEG/PNG/WebP, max 5 MB).
- AI helper API endpoint at `/api/helper`; AI key stays on the server in Vercel environment variables.
- Row Level Security policies for report writes, votes, comments, and storage.

## Required setup before deployment
The ZIP is code-complete but not connected to your Supabase project or OpenAI API account yet. Do these setup steps to enable shared data and AI.

1. Create a Supabase project at https://supabase.com/ and wait until it is ready.
2. Open **SQL Editor → New query**, paste all of `supabase/schema.sql`, and run it once. The SQL creates the tables, access policies, and public photo bucket. Do not share your database password or service-role key.
3. Open **Project Settings → API**. Copy the Project URL and the **publishable/anon key** (not the service-role key). Put them into `public/config.js` as `supabaseUrl` and `supabaseAnonKey`. These values are browser-visible; Row Level Security is essential.
4. In Supabase **Authentication → URL Configuration**, add your deployed Vercel URL to Site URL / Redirect URLs after first deployment. For local testing, add `http://localhost:3000/**`. Depending on your auth settings, sign-up confirmation emails may need to be confirmed before sign-in.
5. Create an OpenAI API key in your own account. In Vercel Project → Settings → Environment Variables add `OPENAI_API_KEY`. Optionally add `OPENAI_MODEL` = `gpt-4o-mini`. Never put the AI key in `public/config.js` or commit it to GitHub. API usage may cost money.
6. Push this folder to a GitHub repository, then import it in https://vercel.com/new. Framework preset: **Other**. Root directory: project root. Build command: leave blank. Output directory: `public`. Install command can be `npm install` (Vercel installs the dev dependency and serverless API). Add the environment variables and deploy.
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


## Guest-first edition
This build removes required resident registration. Before deploying, run `supabase/guest-migration.sql` once in your existing Supabase project. It is designed to preserve existing rows; review it and back up your project first. Guest actions use a random browser ID, not verified identity, so it is a hackathon prototype and needs stronger server-side anti-spam controls before real public use.
