# Google-only authentication verification — 16 November 2026

Status: implemented and tested locally, **not complete or live-Google verified**.

## Current blockers

- Root `.env` exists and is Git-ignored/untracked, but GOOGLE_CLIENT_ID,
  GOOGLE_CLIENT_SECRET, GOOGLE_CALLBACK_URL and AUTH_TRANSPORT_FRONTEND_URL are
  still absent. Real OAuth initiation returns 503 `oauth_not_configured`.
- The configured existing PostgreSQL connection rejects authentication with
  code `28P01`. No credentials or user records were changed. Its account schema
  and authorized account assignments therefore cannot be verified yet.
- The running isolated development database contains no pre-authorized accounts.
  Existing trusted account records with matching stable Google subject and verified
  email must be available before live login can succeed. Login will not create
  accounts, bind an email to a new subject, or select a role automatically.
- A dedicated Student Dashboard, booking, booking history, complaints, feedback
  and notifications APIs/screens
  are not implemented in the inspected transport app or Member 1 service. The
  booking queue adapter explicitly reports that booking integration is absent.
  No fake modules, invented endpoints, or success results were added. Their role
  and record-ownership middleware cannot be integrated until those modules exist.

## Changes

1. Reused the existing OAuth service's scopes (`openid email profile`), state,
   nonce, PKCE, Google code exchange, ID-token verification, institutional identity
   policy, callback, session regeneration, PostgreSQL store, expiry and logout.
2. Added an optional account-directory hook to the shared service. Existing
   Member 1 standalone behavior/tests are preserved; the root authenticated server
   always supplies a strict existing-account directory. Do not deploy the legacy
   standalone registration app as the Google-only system's entry point.
3. The directory SELECTs only a matching `google_subject` and verified email.
   It performs no user writes and resolves only existing roles and explicit
   administrator-provisioned transport mappings. Unknown or mismatched accounts
   fail with `account_not_authorized`. A Driver must have a valid mapped driver ID.
4. `/api/auth/me` now exposes the current server-authorized role for integrated
   Flutter use. Each protected API checks its session and current role. Existing
   driver ownership and trip transition checks remain in force.
5. Flutter retrieves `/api/auth/me` on startup/refresh and before protected
   requests, uses credentialed BrowserClient requests, removes stale session
   navigation, and logs out through the real backend. OAuth callback errors have
   clear user messages. No client secret, local-storage token or role selector exists.
6. The production startup honors AUTH_TRANSPORT_FRONTEND_URL using the existing
   auth config validation. Local CORS allows only the exact Flutter origin with
   credentials. Cookies are HttpOnly and SameSite=Lax; production config requires
   HTTPS and Secure cookies. Production hosting must keep frontend/API same-site
   or separately review cookie policy for its deployment.

## Verification limits

The integrated tests explicitly pre-provision Student, Driver and Authority
accounts in an isolated PostgreSQL engine. They use the production PostgreSQL
session store and exercise login/callback/session cookies, repeated user retrieval,
unknown/unverified/mismatched account denial, preserved roles, direct API access,
cross-role denial, bus/route/trip/driver management, assignment/unassignment,
ownership, real trip start/stop database transitions, expiration, tampered cookies,
revocation, logout, and unauthorized use after logout.

**The Google provider is a test double only within those tests.** Passing them
does not verify real Google credentials, consent, the Cloud Console registration,
or an actual authorized person's login. No authenticated live browser demonstration
can be claimed until those external prerequisites are fulfilled.

The original Member 1 suite passes all 62 tests. The transport suite passes 65
tests, with one real Redis integration test skipped. Flutter analysis is clean;
all 34 Flutter tests pass, including reconstruction from `/api/auth/me`.

## Required local configuration

Configure the following in root `.env`, without sending secrets in chat:

```dotenv
GOOGLE_CLIENT_ID=<existing Google Web OAuth client ID>
GOOGLE_CLIENT_SECRET=<existing Google Web OAuth client secret>
GOOGLE_CALLBACK_URL=http://127.0.0.1:3002/api/auth/google/callback
AUTH_TRANSPORT_FRONTEND_URL=http://127.0.0.1:8191
```

Register that exact callback in the existing Google Cloud Web OAuth client, and
ensure its consent-screen audience/test-user policy permits the eligible BRACU
account. Keep the existing `g.bracu.ac.bd`, verified-email and naming policy.
Repair DATABASE_URL credentials locally if using the existing PostgreSQL server;
review the auth and role-mapping schema with the database owner before applying
anything to a shared database. No shared migration was applied in this task.

The safe local launcher is `node server/scripts/start-isolated-auth.mjs`. It
never connects to DATABASE_URL. It uses a new isolated database and creates no
fake identities, users, role grants or seed records. The actual Flutter app is
served at http://127.0.0.1:8191 using `lib/main.dart` and the API on port 3002.
It is currently kept alive with Flutter's `-d web-server` target and opened in
Chrome independently, because Chrome-managed debug sessions were ending. This
serves the actual Flutter app, not a gallery, custom HTML app or fixture entry point.
After credentials and authorized development accounts exist, manually complete
Google sign-in, then verify the callback, HttpOnly cookie, `/api/auth/me`, page
refresh, role-specific UI and protected API behavior before declaring completion.
