# Verified authentication integration

## Current status

The Flutter entry point uses `AuthenticatedTransportHost` to query `/api/auth/me`
with browser credentials. Only the server response constructs `TransportSession`
and mounts `TransportApp`. JavaScript never reads the HttpOnly cookie, stores
tokens in local storage, or chooses a role. Requests recheck the current session
and reset the privileged app tree when identity or permissions change. Logout
destroys the server session and removes the authenticated Flutter tree.

The integrated Express app reuses Member 1's existing Google provider, identity
validation, OAuth controller/routes, session expiration checks, and auth config.
A small optional account-directory hook was added to Member 1's shared service;
its existing standalone behavior and tests are preserved. The integrated app
always supplies the strict existing-account policy. Cookies retain HttpOnly, SameSite=Lax,
secure-in-production settings and PostgreSQL session store. CORS permits only
the configured frontend origin with credentials; mutations require that Origin.
Helmet security headers are retained. There is no environment driver-identity
bypass on this server.

**Live Google login is not verified:** GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET
are absent. The real running Google endpoint returns HTTP 503
`oauth_not_configured`. No fake provider or authenticated user was installed in
the running application. There are no privileged grants or development records
in the live isolated database yet.

## Roles and provisioning

The existing identity service and `users` constraint support only `student`.
That schema remains unchanged. `transport_account_roles.sql` adds a separate, explicit
server-owned authorization mapping for identities already verified by that
service. Login now requires both Google subject and verified email to match an
existing account. Login performs no user INSERT, UPDATE, linking or role grants.
Without a mapping, the existing users.role is preserved; unsupported roles fail
closed. With the current student-only schema, Authority requires an `authority` mapping;
Driver requires a `driver` mapping with a foreign key to an existing driver.
Identity role and transport permissions are intentionally separate fields.

Student is denied transport management and driver controls, matching the existing
Flutter guards. Authority can list/detail/create/edit buses/routes/trips/drivers
and assign/unassign drivers. Driver can access only their profile/assigned trips
and start/stop their own trips. The existing ownership, inactive-driver,
conflict, and transition checks remain authoritative.

Only a trusted administrator may provision or revoke this mapping. No public
grant endpoint, role picker, email-derived privilege or self-registration grant
exists. A real verified account and explicit account-to-driver linkage are still
required for live Driver/Authority testing. Staff accounts outside the existing
student institutional email policy cannot log in; expanding that identity policy
requires the authentication owner's approval and is not claimed complete here.

## Safe local operation

From the repository root:

```powershell
node server/scripts/start-isolated-auth.mjs
```

This uses a new persistent PGlite PostgreSQL database under
`.local/isolated-auth-transport-db`. It never connects to the configured existing
DATABASE_URL. On an empty database only, it installs the existing auth and
transport schemas plus the reviewed role mapping. It creates no fake accounts,
privileges, drivers, trips, or seed records. Its session signing secret is
ephemeral, so restarting this development helper invalidates old sessions.
It must not be used as a production deployment launcher.

Configure Google credentials locally in root `.env` (never paste secrets in chat):

- GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET for an existing Google Web OAuth client.
- GOOGLE_CALLBACK_URL=http://127.0.0.1:3002/api/auth/google/callback
- AUTH_TRANSPORT_FRONTEND_URL=http://127.0.0.1:8191

Register the exact redirect URI with that OAuth client, configure its consent
screen/test-user eligibility as required by your organization, and restart the
isolated helper. Use `127.0.0.1` consistently for cookies; do not mix localhost
and 127.0.0.1. The existing Google domain and email eligibility checks still apply.

Run the actual Flutter app from `flutter_app`:

```powershell
& 'D:\Bracubus\.local\flutter\bin\flutter.bat' run -d chrome --target lib/main.dart --web-hostname 127.0.0.1 --web-port 8191 --dart-define=API_BASE_URL=http://127.0.0.1:3002/api
```

Native Android transport widgets remain available, but native cookie handling and
browser callback/deep-link login are not implemented by this web integration.

## Existing database deployment

The default `server/src/index.js` now starts the authenticated server, rather than
the previous unauthenticated development app. Startup fails closed unless auth
configuration and all required tables exist. Configure DATABASE_URL, SESSION_SECRET,
GOOGLE_CALLBACK_URL, FRONTEND_URL, GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET using
Member 1's existing config contract. AUTH_TRANSPORT_PORT overrides API_PORT;
otherwise the server defaults to 3002. API_HOST defaults to loopback; production
deployment must explicitly configure its hosting/reverse-proxy settings and HTTPS.

The authentication and transport tables must be in the same database for this
composition. Applying the authentication schema or role mapping to any existing
shared database has NOT been performed. Review schema conflicts, back up, and
coordinate migration/provisioning with the identity and database owners first.
The legacy `createApp` remains a lower-level router composition for existing
tests; do not expose it directly. Our prior unauthenticated port-3000 process was
stopped; old gallery/proxy launchers are not an authentication integration.

## Verification and honest limits

- Flutter analysis: no issues. All 34 Flutter tests pass. Coverage includes session-to-role
  handoff, malformed-role rejection, login UI and logout navigation teardown.
- Transport backend suite: 65 passed, 1 Redis integration test skipped.
- Original Member 1 authentication suite, unchanged: all 62 passed.
- New integrated backend coverage uses the production PostgreSQL session store,
  Express cookies and auth routes, and isolated PostgreSQL records. It checks
  unauthenticated/Student/Driver/Authority restrictions, direct API bypass attempts,
  origin protection, all management modules, assignment/unassignment, ownership,
  real trip start/stop transitions, expiration, tampered cookies, revocation and
  logout. **Only its Google provider is a test double.**
- Actual Chrome verification: login and session retry render, no page exceptions;
  real API requests for session/buses/routes/trips/drivers return 401 without a
  login, Google initiation returns 503 for missing credentials. No browser response
  interception or mock data was used. Screenshot: `.local/real-auth-flutter-home.png`.

This verifies integration code and backend enforcement, not live institutional
Google identity or live authorized-module browser workflows. Those remain pending
credentials, an eligible account, explicit admin grants and isolated test records.
