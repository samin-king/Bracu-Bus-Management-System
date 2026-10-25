# Temporary integrated backend deployment

Use Render's Node web service and a dedicated Neon database. Keep the Render Root
Directory at the repository root: `services` imports the integrated `server`
application and the migration runner reads `database`.

Connect repository `samin-king/Bracu-Bus-Management-System`, branch `main`.
The Blueprint pins `main`; leave Render's Root Directory blank (repository root).

The root `render.yaml` declares the configuration. It does not deploy anything by
itself. Automatic deploys are disabled. Do not commit/push to trigger deployment
until authorized. Render's Git deployment cannot include uncommitted local files;
an account-authorized alternative is a container image built from this workspace.

## Required access and values

- Render deployment access and a source/image deployment method.
- A dedicated Neon database and its direct TLS connection string. Preserve Neon's
  supplied TLS parameters; do not disable certificate verification. Do not use the
  existing local database as the hosted database.
- SMTP credentials, a verified sender, and permission to send to the demo inboxes.
  Render Free blocks outbound ports 25, 465 and 587. The supplied configuration
  requires a provider supporting STARTTLS on port 2525. If unavailable, choose an
  SMTP-capable hosting plan instead; do not replace email verification with a bypass.
- Three distinct real `@g.bracu.ac.bd` inboxes in `DEMO_STUDENT_EMAIL`,
  `DEMO_DRIVER_EMAIL`, and `DEMO_AUTHORITY_EMAIL`. The operator explicitly provisions
  these roles; login cannot grant itself a role. Existing incompatible roles/driver
  links cause provisioning to fail rather than being overwritten.
- Vercel project deployment access to publish the rewrite after the API URL exists.

Use `.env.production.example` as the environment reference. Store actual secrets in
hosting secret settings, never in this repository. Render generates SESSION_SECRET
and supplies PORT. Leave GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET unset; the HTTPS
GOOGLE_CALLBACK_URL satisfies legacy config validation without enabling OAuth.

## Startup and demo data

Build: `npm ci --omit=dev --workspace services --workspace server`.

Start: `npm run migrate && node services/scripts/seed-demo.js && npm run start --workspace services`.

The migration command applies all existing migrations transactionally, with an
advisory lock. The explicit demo seed is transactional and repeatable. It adds two
buses (28/37 seats, four standing places each), one route, an active driver, linked
accounts, and trips at the four supported times today through five days ahead.
It also adds clearly labeled sample complaint, feedback and notification records.
It does not create sessions, login tokens or confirmed bookings. Student gender is
initially unverified and is set through the existing Profile screen. Repeated runs
preserve profile edits and existing account roles. Booking must be demonstrated in
an actual server-side booking window; there is no clock or booking bypass.

No Redis worker is needed for the existing synchronous complaint/feedback/notification
APIs. The web process is the integrated `services/src/server.js`, not a standalone
transport application.

## Vercel routing

`Client/vercel.json` contains the API rewrite followed by a frontend-only SPA
fallback. Configure the Vercel project's Root Directory as `Client`, using the
Vite build (`npm run build`) and output directory `dist`. Verify this setting in
the existing Vercel project: it cannot be determined from repository files.
If that project instead builds from the repository root, move this configuration
to root `vercel.json` and use root build `npm run build` with output `Client/dist`;
do not keep competing copies of the configuration.

Before deploying, replace **only** `replace-with-render-backend-host.invalid` in
`Client/vercel.json`, first rewrite's `destination`, with the actual Render
hostname (for example, the hostname supplied by Render, without a scheme or path).
The reserved `.invalid` hostname is an explicit nonfunctional placeholder, not a
real backend URL. Leave `https://` and `/api/:path*` intact.

```json
{
  "rewrites": [
    {"source": "/api/:path*", "destination": "https://replace-with-render-backend-host.invalid/api/:path*"},
    {"source": "/((?!api(?:/|$)).*)", "destination": "/index.html"}
  ]
}
```

The API rewrite matches `/api` and `/api/...`. The fallback explicitly excludes
both, so failed API requests cannot turn into successful index.html responses.
The fallback serves frontend deep links such as `/login`, `/profile` and `/driver`.
This configuration is not ready for a working public demo until the real host is known.
Do not introduce frontend API environment variables. FRONTEND_URL must remain
`https://bracu-bus-management-system.vercel.app` so the existing mutation-origin
check accepts the browser's Origin. No browser CORS change is needed for this
same-origin proxy. Verify that the rewrite preserves Origin and Set-Cookie, and
that the trusted hosting proxy forwards HTTPS correctly for secure cookies.

## Lockfile casing review

Git and package.json name the frontend workspace `Client`, but package-lock.json
currently records `client` and links `node_modules/transport-client` to `client`.
Windows can hide this mismatch; a case-sensitive Linux installation can resolve
the wrong or nonexistent workspace path. The backend-only install must still be
verified in a clean Linux environment; a Windows build does not prove that check.

The lockfile has intentionally not been changed in this deployment update. The
required correction, if authorized, is to regenerate package-lock.json in a clean,
case-sensitive checkout with `Client` as the workspace directory, verify that the
workspace entry, nested entries and transport-client link all use `Client`, review
the dependency diff, and check both the backend install command and frontend build.
Do not rename the application directory or manually replace unrelated text.

## Public acceptance checks

1. Direct API `/api/auth/me` returns JSON 401 without a session. This is expected,
   not a health endpoint returning 200. Development login returns 404. An unexpected
   Origin is rejected on email POST. Never log real tokens or cookie values.
2. Through the Vercel URL, request and redeem the student's real email link. Check
   authenticated `/api/auth/me`, refresh persistence and token replay rejection.
3. Save/read the student's gender profile; read trips and seat availability.
4. Within a real booking window, book an eligible seat/standing place, read history,
   cancel it, and confirm capacity is released. Outside the window expect rejection.
5. Log in using the driver's actual email link and verify assigned trips/dashboard.
6. Submit/read a complaint and feedback. Using the authority inbox, respond to the
   complaint, then check the student's notification and mark it read.
7. Logout, then confirm `/api/auth/me` is 401. Repeat using public Chrome against
   the Vercel frontend, including refresh and protected routes.

Render Free sleeps after 15 idle minutes (roughly a minute to wake), has ephemeral
disk and monthly instance/bandwidth/build limits. Neon Free has usage quotas and
scales down when idle. These are demo services, not production availability promises.
Hosted provisioning and end-to-end acceptance remain pending until account access,
SMTP and actual inbox verification are available.
