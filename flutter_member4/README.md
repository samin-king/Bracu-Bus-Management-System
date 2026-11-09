# Member 4 Flutter frontend

An Android-compatible Flutter feature package. This checkout contains no Flutter
host app, Android runner or Member 1 authentication implementation. Import these
screens into the migration's host app; this package does not create a second login
or alter backend authentication. Backend and database files are unchanged.

For the inspected host-availability report, exact required interfaces, navigation
constraints and remaining readiness gates, read [INTEGRATION.md](INTEGRATION.md).
The main Flutter host is not present in this checkout, so final compatibility
and authenticated Android acceptance remain unverified.

Add a path dependency in the host's pubspec:

```yaml
dependencies:
  bracu_member4:
    path: ../flutter_member4
```

Create the API wrapper once in the host's existing DI lifecycle, using its
authenticated client. Wrap the existing application/Navigators with the session;
the names below illustrate required host inputs:

```dart
import 'package:bracu_member4/member4.dart';

// Create once, outside ordinary widget builds:
final member4Api = Member4Api(
  baseUrl: existingApiRoot, // Existing configured Uri ending in /api/.
  client: existingAuthenticatedHttpClient,
);

// Rebuild this scope from the existing host's reactive session state:
Member4Session(
  api: member4Api,
  authenticated: existingSession.isAuthenticated,
  role: existingSession.verifiedRole,
  sessionKey: existingSession.accountSessionKey,
  child: existingApplication,
)
```

Register the exported screens in the existing host router; do not add a second
MaterialApp. INTEGRATION.md gives the route/role matrix and notes for nested
Navigators, root dialogs and existing shell app bars. These examples are not
claims about host classes that are absent from this repository.

Use the existing auth module's `package:http` Client (or its adapter) that adds the
real session/token. The host owns and closes the client. Keep the API instance
stable during ordinary rebuilds. The required `sessionKey` is an opaque, stable
value provided by the host for one account/session. Change it on sign-out or
account switch, even if the API/client is reused. It is never sent to the server.
The names `existingSession` and `accountSessionKey` above illustrate host inputs;
they are not a new authentication implementation or package-provided APIs.
No `user_id`, `role`, `x-user-id` or `x-role` is sent. UI guards improve navigation;
the existing server enforces authentication, ownership and roles. Use HTTPS and
the host Android application's existing INTERNET permission. For local emulators,
configure an accessible server URL in the host (localhost means the emulator).

## Existing APIs reused

All paths below are relative to `/api/`:

* GET/POST `complaints`, GET `complaints/:id` (student only).
* GET `authority/complaints`, GET/PATCH `authority/complaints/:id`
  (authority/admin only); category/status/search filters.
* GET/POST `feedback` (student only).
* GET `notifications`, GET `notifications/unread-count`,
  PATCH `notifications/:id/read`, PATCH `notifications/read-all`
  (any authenticated user).

Lists page with limit 50 and offset. Forms match the five categories, four
statuses, four feedback targets, integer ratings 1–5, 5000 UTF-16 character text
limits, and positive 32-bit IDs. Foreign-key existence is validated by the server.
Only the selected feedback target reference is submitted. Blank optional feedback
comments are allowed; whitespace-only comments are rejected as on the backend.
An empty authority response is omitted to preserve the existing response, as in
React; the API does not support clearing a response with an empty string.

Screens include progress, errors, retry, empty states, disabled duplicate submits,
pull-to-refresh, toolbar refresh, paging, submission confirmations and details.
Notification details use the list record and do not automatically mark it read.
The session must sit above every Navigator that opens these screens, including
the root Navigator used by notification dialogs. Existing application route guards
can remain in place alongside the feature's guards.

## Presentation and request behavior

The screens inherit the host's Material theme, color scheme, typography and dark
mode. Shared cards, outlined inputs, semantic status chips, success/error banners
and notification icons keep the feature consistent with the main app. Content is
centered at a maximum width of 760 logical pixels, uses safe areas and scrolls on
small phones. Page controls wrap for larger text sizes. Text limits and counters
use UTF-16 code units to match JavaScript validation, including emoji.

Reads and mutations cannot overlap. A pending initial load disables submission.
After a successful submission the form clears, page 1 reloads and confirmation is
revealed. A failed follow-up read leaves the successful submission confirmation
visible alongside a read error; retry refreshes data without resubmitting.
Failed saves preserve drafts. A 401/403 hides records and feature controls; the
host remains responsible for updating its real session and handling expiry.
Account changes discard drafts/results and hide already-open notification detail
content. Complaint details refresh when reopened; lists refresh on returning.

Only changed status/response fields are sent by management. Blank responses are
omitted and unchanged saves make no request. A retry after a failed page load
uses that page's offset. There is no total-count endpoint, so a full 50-item page
enables Next; the following page can be empty.

Requests have one configurable overall timeout (default 30 seconds) and do not
automatically retry writes. A timed-out write may still complete on the server;
refresh existing history before manually submitting again. UTF-8 JSON and
response shapes are validated before records reach the widgets.

## Backend limitations

* Complaint history is a list of submissions with current status/latest response,
  not an audit timeline or conversation. No audit endpoint exists.
* Notifications have no detail endpoint, unread reversal, deletion, public send
  endpoint, device push subscription, or live stream. Refresh is explicit.
* No feedback edit/delete, attachments, complaint delete or student status update.
* Only real complaint changes currently generate notifications; no events are
  simulated for booking, transport or other modules.
* The server composition defaults to no user verifier and returns 401. A real
  authenticated deployment supplied by Member 1 is needed for live acceptance
  testing. This package deliberately does not change that server configuration.

## Checks

Requires Flutter 3.22+ and Dart 3.4+; the host's SDK resolves compatible dependency
versions from pubspec.yaml. From this directory, with Flutter installed:

```powershell
flutter pub get
flutter analyze
flutter test
```

After the checks pass, integrate using the authenticated host client and validate
student, authority/admin, and other-user notification flows on an Android device
or emulator. This is a feature package, not a standalone Android application;
there is deliberately no login screen, Android runner, production URL, or token.

Tests use injected HTTP transports and test-only identity fixtures. They never
connect to PostgreSQL/Neon. Live authenticated Android acceptance testing remains
dependent on the host app and its real authentication integration.
