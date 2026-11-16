# BRACU Transport Android

Flutter Android frontend using the repository's existing Express authentication,
PostgreSQL sessions, and transport APIs. Authentication and transport share one
Dio client and one secure, expiring cookie jar.

## Implemented authentication

- Email-link login for existing registered Student, Driver, Authority, and Admin accounts.
- Explicit confirmation of incoming email links, or manual paste of a link/token.
- Secure cookie persistence through Flutter Secure Storage; startup restores identity
  by asking the backend, never by trusting a saved role or profile.
- Session revalidation on resume and periodically while authenticated.
- Logout through the backend, cookie deletion, and removal of protected navigation.
  Failed logout remains retryable rather than falsely reporting success.
- One router with server-assigned roles, protected screens, and stack reset on
  logout, account/role change, or protected HTTP 401. HTTP 403 preserves the session.
- Optional Google sign-in through the system browser and existing backend OAuth
  flow, including callback origin/path/state validation.
- Actionable network/storage errors, retry, and invalid/expired-link feedback.

Existing transport screens and architecture are preserved. No new production
backend endpoints, passwords, fake login, client-selected identities, or
mobile authentication bypasses were added.

## Roles

| Server role | Destination |
| --- | --- |
| student | Signed-in Student handoff screen; Student business features are not yet implemented in Flutter |
| driver | Existing Driver Dashboard, assigned trips, and permitted start/stop controls |
| authority | Existing bus, route, trip, driver, and assignment management |
| admin | Same management screens, retaining Admin as the actual server identity |

Unknown roles fail closed. The backend remains responsible for authorization and
Driver linkage. Google uses the existing backend's Student-only account policy;
registered staff should use email-link login.

## Requirements

- Flutter >=3.38.0 and Dart >=3.10.0 <4.0.0, as declared in pubspec.yaml.
- Verified here with Flutter 3.47.9 / Dart 3.13.7 on Windows.
- Node.js and root npm dependencies for backend and contract testing.
- Android SDK and a device/emulator for Android execution; minimum Android API 24 (required by flutter_secure_storage 11.2).
- A configured existing backend with migrations applied and legitimate accounts.

## Local Android toolchain

On this Windows checkout, dot-source the environment helper before Flutter commands:

~~~powershell
cd A:/Bracubus-integration/flutter_app
. ./tool/android-env.ps1
flutter doctor -v
java -version
adb devices -l
flutter emulators
~~~

The helper updates only the current shell. The portable JDK, Android SDK, and
Gradle cache live under ignored .local/android-toolchain/ in the repository root.
It also locates the existing sibling Flutter SDK. On another machine, pass explicit
-FlutterSdk, -AndroidSdk, and -JavaSdk paths, or supply the supported environment
variables documented in the script. Downloaded tools are not committed.

The local toolchain now includes Microsoft OpenJDK 21, Android command-line tools,
platform-tools, Android platform 36, and build-tools 36.0.0. Required SDK licenses
were accepted. No physical Android device or configured AVD was detected.

## Backend setup

From the repository root:

~~~powershell
npm ci
Copy-Item .env.example .env
# Configure the private .env before continuing.
npm run migrate
npm run dev
~~~

Required backend configuration includes DATABASE_URL, a random SESSION_SECRET of
at least 32 characters, and FRONTEND_URL. Real email delivery requires SMTP_HOST,
EMAIL_FROM, the provider's SMTP port/TLS settings, and usually SMTP_USER and
SMTP_PASSWORD. Keep these values on the backend.

Email login sends a one-time link for an existing registered account. A 202 response
means to check email; it does not establish authentication or guarantee that the
address exists. Links expire after ten minutes and are consumed once. Roles and
Driver links are assigned through trusted administration.

Optional Google OAuth requires GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, and
GOOGLE_CALLBACK_URL on the backend. Register the exact callback URI with Google.
The backend retains state, nonce, PKCE, institutional account checks, and session
rotation. The app does not store Google credentials or use Bearer tokens.

Keep DEV_DIRECT_LOGIN, DEV_EMAIL_LOGIN, and ENABLE_DEV_DRIVER_AUTH disabled for
normal authentication verification. This Flutter app does not call bypass endpoints.

## Flutter public configuration

From flutter_app/:

~~~powershell
Copy-Item config/auth.example.json config/auth.local.json
flutter pub get
~~~

Edit only these public values in the ignored local file:

| Key | Required value |
| --- | --- |
| AUTH_API_ORIGIN | Existing API origin without /api or a trailing path |
| AUTH_FRONTEND_ORIGIN | Exact origin configured as backend FRONTEND_URL; used for mutation Origin checks |
| AUTH_CALLBACK_URL | Empty to hide Google login, or the exact HTTPS API URL ending /api/auth/google/callback on port 443 |
| AUTH_ALLOW_LOCAL_HTTP | Development-only opt-in for loopback or the standard Android emulator; ignored by environment configuration in release builds |

Never put database URLs, SMTP credentials, session secrets, Google client secrets,
or signing keys in Flutter configuration or assets.

Standard Android emulator development can use API origin http://10.0.2.2:3000,
frontend origin http://localhost:5173 when that is the backend FRONTEND_URL,
an empty Google callback, and AUTH_ALLOW_LOCAL_HTTP=true. Debug permits local
HTTP; the main/release manifest denies cleartext traffic. Google requires HTTPS.

Run:

~~~powershell
flutter run --dart-define-from-file=config/auth.local.json
~~~

## Android email links and Google callbacks

The application ID is edu.bracu.bracu_transport. Before running with automatic
link capture, set the real public hosts through Gradle properties:

~~~powershell
$env:ORG_GRADLE_PROJECT_authFrontendHost = 'your-frontend.example'
$env:ORG_GRADLE_PROJECT_authCallbackHost = 'your-api.example'
flutter run --dart-define-from-file=config/auth.local.json
~~~

The MainActivity filter handles the frontend /login path. The Google plugin's
separate CallbackActivity handles /api/auth/google/callback on the API host.
Both exported activities have empty taskAffinity. The browser integration supplies
the HTTPS host and path required by flutter_web_auth_2 5.x; see the
[plugin documentation](https://pub.dev/packages/flutter_web_auth_2/versions/5.1.0).

Complete hosting/assetlinks.example.json with the installed app's signing
certificate SHA-256 fingerprint. Publish it directly as JSON, without redirects,
at /.well-known/assetlinks.json on the frontend host and, when enabling Google,
the API callback host. If both origins share a host, one association file suffices.
The supplied file is a template; no domain association was published here.

Google starts through the native API client, preserving the backend OAuth session
cookie. The browser returns the authorization callback to the app; the app sends
it to the existing backend using that same cookie, then verifies the resulting
session with /api/auth/me. Browser cookies are not assumed to be native API cookies.

Email tokens are accepted from the configured frontend /login fragment, held in
memory, and require confirmation. Published route information omits the token.
Pasting a complete link or token also works without automatic App Link capture.
Invalid, duplicate, malformed, unsupported-scheme, or expired links cannot grant
access. Google callbacks require matching state and exactly one nonempty code or
error; ambiguous callbacks are rejected before the callback API request.

Configure real release signing before distribution; the existing Gradle release
configuration still uses a debug signing placeholder.

## Verification

From the repository root:

~~~powershell
npm test
~~~

From flutter_app/:

~~~powershell
flutter analyze
flutter test --timeout=2m

# Include real Dio-to-Express contracts after installing root npm dependencies:
$env:BRACU_BACKEND_CONTRACT = '1'
flutter test --timeout=2m
~~~

BRACU_TEST_NODE may specify an explicit Node executable. Without the opt-in, six
backend contract cases are skipped. The contract server mounts the actual existing
Express application and migrations against ephemeral PGlite PostgreSQL, with
memory sessions and captured email. It does not load .env, contact an application
database, send real email, or add production authentication endpoints.

Tests cover shared cookies/Origin, session restoration and expiry, all four roles,
unknown roles, protected 401 versus 403, logout/replay and concurrency, stale
identity/cookie rejection, navigation reset, Google callback validation and denial,
network recovery, malformed links, and transport feature regression coverage.

## Authentication review changes - 9 November 2026

Already present: email login, shared secure cookies, restoration, logout,
protected role navigation, Google browser/callback integration, transport screens,
and authentication/navigation/backend contract tests.

This review changed:

- lib/providers/auth_provider.dart: retain safe HTTP error feedback, clear stale
  connection errors on retry, explain malformed links through startup, and guard
  unsupported URI schemes before origin evaluation.
- lib/services/auth_service.dart: require exactly one nonempty Google callback
  code or error and reject duplicate, mixed, missing, or oversized code values.
- lib/services/auth_failure.dart: make Origin rejection feedback apply to all
  affected authentication operations.
- test/session_auth_test.dart: add 13 authentication regression cases covering
  callback ambiguity, browser cancellation/denial, network recovery, malformed
  links, startup feedback, and unsupported link schemes.
- test/backend_contract_test.dart: add a real Express/Dio check for one-use email
  tokens and rejection after logout/replay or malformed-token submission.
- README.md: replace historical worktree notes with current setup and verification.

Existing working-tree changes were preserved. No production backend source,
application database, credentials, package dependencies, or transport features
were changed by this review.

## Results - 9 November 2026

| Check | Result |
| --- | --- |
| flutter analyze | Passed; no issues |
| flutter test --timeout=2m with BRACU_BACKEND_CONTRACT=1 | 77 passed, 0 failed, 0 skipped; includes six real Express/Dio contracts and all original transport tests |
| npm test: authentication/student backend | 135 passed, 0 failed, 3 optional external PostgreSQL checks skipped |
| npm test: transport backend | 73 passed, 0 failed, 1 optional live Redis check skipped |
| git diff --check | Passed |
| flutter doctor -v: Android toolchain | Passed after local JDK/SDK installation; all Android licenses accepted; no Android device/emulator detected |

An intermediate regression run exposed stale network-error feedback after a
successful retry; this was fixed and the full final Flutter suite passed.
Backend tests used their existing isolated test engines. No TEST_DATABASE_URL or
TEST_REDIS_URL was supplied, so those external-service checks remain unverified.

## Remaining external verification

- Android APK build/install and actual emulator/device navigation.
- Android Keystore persistence across process death/restart and cookie expiry.
- Actual SMTP delivery, inbox link opening, expired links, and one-use behavior.
- Hosted Digital Asset Links and automatic email-link capture, cold and warm start.
- Real Google consent, cancellation, HTTPS Auth Tab callback capture, browser
  compatibility, and backend session completion with deployed OAuth credentials.
- Release signing and release-mode HTTPS behavior.

The Android SDK was initially unavailable and has now been installed locally.
Mocked secure storage and browser tests do not establish device behavior.
Production readiness is not claimed.
