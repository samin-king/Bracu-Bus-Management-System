# Member 4 host integration compatibility report and guide

Inspected: 9 November 2026. **Status: prepared for host integration review, not
verified for final integration.** The main Flutter app is absent from this
checkout. No host wiring or production Dart code was changed for this report.

## 1. Evidence and compatibility report

Before changes, the project structure, REVIEW.md, VERIFICATION.md, README.md,
pubspec.yaml, package exports, API client and session interface were inspected.
A search including hidden/ignored source files (excluding dependency/Git caches)
found no other Flutter pubspec, Dart sources or host lockfile in this repository.

| Project area | Observed implementation | Compatibility finding |
|---|---|---|
| `flutter_member4/` | Flutter feature package `bracu_member4`; no Android runner | Import into the real app; do not create another app here. |
| `Client/` | React/Vite frontend | JavaScript browser fetch cannot serve as the Dart authenticated client. |
| `Client/src/services/api.js` | Browser `fetch('/api/' + resource)` | Mobile needs the host's existing absolute API URL and session-aware transport. |
| `Client/src/main.jsx` | React state selects pages | Does not establish the missing Flutter router's API or route names. |
| `Bracu-Bus-Management-System/` | No files present | No alternate Flutter host available here. |
| Dart host authentication/client/role model | Not present | Exact imports, provider selectors and role mapping cannot be determined. |
| Host SDK/dependencies | No host pubspec/lockfile; local Flutter/Dart commands unavailable | Minimum SDK and `http` constraints require validation in the real host. |
| `server/src/index.js` and `server/src/app.js` | Local composition does not install a Member 4 user verifier | A valid authenticated deployment/integration is a prerequisite. A client token alone cannot supply the server's verified identity. |

Backend files were read only. Do not edit the backend to fit this feature package.
The authentication owner must identify the existing authenticated environment.
No missing verifier, session endpoint or login implementation is created here.

### Confirmed package interfaces and unresolved host mappings

| Member 4 interface | Required host source | Current result |
|---|---|---|
| `Member4Api.client: http.Client` | Existing authenticated HTTP transport | Missing. Must support auth through `send(BaseRequest)`, not only convenience `get/post` wrappers. |
| `Member4Api.baseUrl: Uri` | Existing environment/API configuration | Missing. Absolute HTTP(S) API root with trailing slash, normally `/api/`; no credentials/query/fragment. |
| `Member4Session.authenticated: bool` | Existing reactive, verified authentication state | Missing. Do not infer from token presence alone or from local role selection. |
| `Member4Session.role: String?` | Existing verified user-role model | Missing. Exact accepted values: `student`, `authority`, `admin`; notifications require any authenticated user. |
| `Member4Session.sessionKey: Object` | Existing account/session identity or epoch | Missing. Stable during one session, changed on logout/account switch. Never sent in an API request. |
| `Member4Session.api: Member4Api` | Host dependency-injection lifecycle | Create once for the current client/base URL; keep stable across ordinary rebuilds. |
| Existing Navigator/router | Host entry point, router and shell | Missing. Session must cover pushed detail routes and root notification dialogs. |

There is no confirmed host-side dependency conflict because no host dependencies
are available. Conditional mismatches to check when the source is supplied:

* A Dio client or custom repository is not an `http.Client` and cannot be passed
  directly. Identify an existing host adapter or design a transport-only bridge
  after reviewing that client. The bridge must reuse the same credentials,
  refresh/session behavior and error handling. Do not instantiate a second login
  or independent network/auth stack. No speculative adapter is included here.
* A role enum or differently named role field needs an explicit mapping from the
  verified host account model. Do not guess aliases or grant broader roles.
* An older SDK or incompatible `http` pin must be resolved against the actual
  host pubspec. Do not add dependency overrides just to suppress a conflict.
* Declarative routing, nested Navigator keys, deep links and host shell layout
  must be checked against the real router. Member 4 currently uses imperative
  detail pushes; it does not supply router-specific deep-link definitions.

## 2. Source and configuration needed from the host owner

Provide the existing host's location/branch plus these interfaces before wiring:

1. `pubspec.yaml`, lockfile and SDK version.
2. App entry/composition root and the existing router/Navigator configuration,
   including root/child Navigator keys and existing route guards.
3. Authenticated HTTP client type and construction/lifetime, particularly the
   `send`/interceptor path, token/cookie handling, refresh and retry policies.
   Provide code/configuration names, not production secrets.
4. Reactive session/account model: authentication state, verified role type,
   stable account/session identifier, and logout/account-switch notifications.
5. Existing API-root configuration and the authenticated test environment.
6. Host Android network configuration and an emulator/device test target.

Until those exist, exact class names, imports, router calls and session selectors
cannot be truthfully specified. The guide below defines the required boundary.

## 3. Add the package dependency in the host

The host owner should add the path dependency using the actual relative location:

```yaml
dependencies:
  bracu_member4:
    path: ../flutter_member4
```

This path assumes sibling host/package directories; adjust it for the real
checkout. Member 4 requires Flutter >=3.22.0, Dart >=3.4.0 <4.0.0 and `http
^1.2.2`. `flutter_test` is a development dependency. Provider, Riverpod, Bloc,
GoRouter and Dio are not required or added by this feature.

The host imports the feature through:

```dart
import 'package:bracu_member4/member4.dart';
```

## 4. Reuse the authenticated transport and scope its lifetime

The following is a boundary example using host-provided inputs; the names are
placeholders, not new auth/configuration APIs. It is not a new application entry
point or a drop-in patch for an uninspected host.

```dart
// In the existing host DI/composition lifecycle, not inside build():
final member4Api = Member4Api(
  baseUrl: hostApiRoot, // Existing configured Uri, ending in /api/.
  client: hostAuthenticatedHttpClient, // Existing http.Client instance.
);

// In the existing reactive host composition; rebuild when session changes:
Member4Session(
  api: member4Api,
  authenticated: hostSession.isAuthenticated,
  role: verifiedRoleForMember4,
  sessionKey: hostAccountSessionKey,
  child: existingApplication,
)
```

Keep the existing application, theme and router. Do not create a second
MaterialApp, client, auth provider, login screen, role selector or token store.
If auth is provided inside the app, place the scope in the host's existing
composition/builder where both session dependencies and all relevant Navigators
are available: the scope must read the existing session dependencies and wrap
all relevant Navigators. For either MaterialApp or MaterialApp.router, its existing
builder can wrap the navigator/router child; preserve any existing builder.
The exact placement needs the real widget tree.

The host owns and disposes its HTTP client. Member 4 does not close it. Replace
the API instance if the client or configured backend changes. Do not reconstruct
it on every build, because that intentionally resets feature page state.

Verify that the existing client applies authentication to `send()` and preserves
the JSON/Accept headers and methods used here. Confirm that its retry policy does
not replay complaint/feedback submissions automatically. Member 4 sends no
`user_id`, `role`, `x-user-id` or `x-role` claims and does not verify tokens itself.

### Session lifecycle

* **Initial signed-out/auth-loading state:** pass authenticated=false and the
  host's current session boundary. Feature guards do not fetch protected data.
* **Login:** pass the verified role and signed-in session key from host state.
* **Ordinary rebuild/token refresh for the same account:** keep the key/API
  stable unless the host replaces its client. Never use a random key per build.
* **Logout/account switch/new login:** change the key even if reusing the same
  client and role. The boundary must include an existing session generation or
  equivalent if the same account can sign out and sign in again.
* **401/403:** Member 4 hides feature data and reports the server error. The host
  continues to handle refresh/expiry/logout through its existing mechanisms;
  Member 4 does not mutate or replace host authentication state.

The key is only a widget-state boundary, not a credential. Old requests are not
forcibly canceled on a shared host client; disposed pages ignore their results.
Already-sent mutations may still complete on the server. The host's normal route
and session teardown policies remain relevant.

## 5. Add screens to the existing host navigation

Use the host router's own registration API and existing route guards. Suggested
paths below are examples; first check for conflicts with its current route names.

| Suggested route | Screen builder | Allowed verified session |
|---|---|---|
| `/complaints` | `(_) => const ComplaintsScreen()` | student |
| `/complaints/manage` | `(_) => const ComplaintManagementScreen()` | authority or admin |
| `/feedback` | `(_) => const FeedbackScreen()` | student |
| `/notifications` | `(_) => const NotificationsScreen()` | any authenticated user |

The feature also exports `ComplaintDetailScreen(id: ..., management: ...)`.
Students use management=false and the own-complaint endpoint; authority/admin
use management=true and the authority endpoint. Do not route students through
management=true to bypass ownership. Server checks remain authoritative.

Complaint lists currently push MaterialPageRoute details on the nearest
Navigator; notifications use a root-Navigator dialog. Place the session above
both. Confirm back navigation and logout behavior with the actual host router.
Do not claim web/deep-link synchronization or state restoration without testing
that router. Feature screens provide their own Scaffold and AppBar; decide with
the host shell whether to register them as full pages or use its existing page
container, avoiding duplicated app bars. No shell redesign is made here.

Expose only the role-appropriate navigation entries. A driver may open personal
notifications but has no complaint submission, feedback submission or complaint
management access. Hiding an entry supplements, but never replaces, server
authorization and the package's guards.

## 6. API and Android connection

Reuse only existing paths under the configured API root:

* GET/POST `complaints`; GET `complaints/:id`.
* GET `authority/complaints`; GET/PATCH `authority/complaints/:id`.
* GET/POST `feedback`.
* GET `notifications`; GET `notifications/unread-count`.
* PATCH `notifications/:id/read`; PATCH `notifications/read-all`.

No new endpoint is needed. Lists return arrays with limit=50 and offset=page*50.
Notification details use list data. Complaint history shows current status/latest
response rather than an unsupported audit timeline. See README.md for limits.

Use the host's configured absolute API root once: a base ending `/api/` plus
`complaints` resolves to `/api/complaints`, not `/api/api/complaints`. HTTPS is
preferred for the real environment. Confirm the host Android runner already has
INTERNET permission and the intended network policy. Do not broadly enable
cleartext traffic or add networking configuration blindly.

On an emulator/device, localhost refers to that emulator/device. Use the host's
existing reachable development URL configuration. Browser same-origin fetch and
its cookies do not automatically transfer to an Android HTTP client; the real
host transport must already manage the actual session method.

The inspected local backend has no Member 4 user verifier installed by its
entry point, so protected Member 4 requests default to 401. This guide does not
change that behavior. Obtain the existing authenticated deployment or the
authentication owner's completed integration before live acceptance tests.

## 7. Verification and readiness gates

Current findings are source-level compatibility checks. Flutter/Dart were not
available on PATH at this inspection, and there is no resolved host dependency
graph. This task does not establish a new Flutter test pass or Android build.

With the real SDK, run in the feature package:

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
```

Then run dependency resolution, analysis, relevant tests and the existing Android
build/run procedure in the actual host. Fix any SDK/dependency/router mismatches
before merging. Test with real verified accounts:

| Check | Expected result |
|---|---|
| Student complaint submission/history/detail | Correct own records; validation and latest response visible |
| Authority/admin management | Filters/details and supported status/response PATCH only |
| Student feedback | Correct target/rating/reference; success/error/history |
| Personal notifications | Refresh, pagination, unread count, details, read one/all |
| Unauthorized roles/expired session | No forbidden operation; server 401/403 handled by feature and existing host lifecycle |
| Logout/account switch, including an open dialog or pending request | Old details/drafts/results not exposed to the next session |
| Failed save/failed refresh/offline state | Draft retained; read retry does not replay successful writes |
| Back navigation and shell | Correct Navigator, no missing scope or duplicated app bars |
| Small Android screen/enlarged text/keyboard | Readable forms, status indicators and controls without overflow |

**Final readiness:** the package boundary and guide are prepared. Final
integration is blocked until the host source/interfaces and authenticated test
environment are available, dependency/SDK checks pass, and integrated Android
acceptance is completed. No host auth or routing implementation is fabricated.
