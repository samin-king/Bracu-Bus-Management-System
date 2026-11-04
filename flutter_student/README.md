# Flutter Student Booking module

Frontend-only Flutter package for an Android host. All new files are under
`flutter_student/`; existing React, backend, SQL and other local changes are untouched.

## Integrate with the authenticated Android app

This repository has no existing Flutter host/authentication module. Add this package
as a path dependency to that host and use `StudentBookingApp` from `lib/main.dart`,
or embed `StudentBookingScreen` using an owned `BookingState`.

```dart
final api = HttpStudentApi(
  baseUrl: Uri.parse(apiServerUrl),
  frontendOrigin: configuredFrontendOrigin,
  sessionCookie: authSession.existingCookieHeader,
);
runApp(StudentBookingApp(api: api));
```

`authSession.existingCookieHeader` is supplied by the authentication owner: a
`Future<String> Function()` returning the existing authenticated Cookie header.
Do not embed a cookie in source or build configuration. Use the backend's exact
configured FRONTEND_URL for Origin; the existing backend requires it for writes.
The host needs Android INTERNET permission and an HTTPS backend reachable from the
device. No new login, API, backend setting, migration or booking rule is introduced.
This package is not a standalone authenticated APK.

## Existing APIs reused

All calls use `/api/student` and the existing session:

- `GET /trips?date=YYYY-MM-DD`
- `GET /trips/:id/seats?date=YYYY-MM-DD`
- `POST /bookings` with only `tripId`, `travelDate`, `seatNumber`, `standing`
- `GET /bookings`
- `GET /bookings/:id`
- `POST /bookings/:id/cancel` with `{}`

No fare, identity, capacity, QR payload or booking-window decision is submitted.
Availability's `selectable` and `standingAvailable` determine selection. Closed
windows still allow review; Confirm & Book is disabled. Immediately before POST,
the app rechecks server availability and shows backend rejections. A synchronous
busy guard prevents duplicate calls. Network failures are not automatically retried;
an uncertain write blocks further submission for that state instance and directs
the student to history. The backend remains the concurrency authority.

History/details are fetched from the server on navigation, refresh and app resume.
There is no local booking persistence to override server state. Cancellation applies
the response immediately, hides any injected ticket and refreshes availability/history.
If an external cancellation happens while the screen is open, resume or refresh
revalidates it; there is no existing realtime cancellation API.

## Missing source contracts: QR and fare

Inspected `Member2.jsx`, `member2Api.js`, `member2Service.js`, `bookingRules.js`,
`member2Routes.js`, schema 002 and existing booking tests. SeatMap.jsx,
BookingReview.jsx, BookingTicket.jsx and StudentProfile.jsx do not exist in this
checkout. Their booking concerns are currently inline in Member2.jsx.

There is **no existing QR-ticket implementation** and no QR, ticket or fare fields
in the booking schema/service responses. There is also no BDT 120 server-side fare
logic in this checkout. Therefore real QR reuse, immediate confirmed QR display,
and server-confirmed BDT 120 display are blocked on the correct source/contract.
No fake QR, guessed ticket endpoint, local QR encoding, or invented fare is added.
The UI explicitly reports missing QR/fare data.

`ConfirmedTicketBuilder` is an integration boundary for the existing renderer once
provided. It receives only an actual server booking and is never invoked for a
cancelled booking. It is not itself a QR implementation. Do not connect a renderer
that manufactures a payload from an ID without the existing ticket contract.

## File inventory

- `lib/models/booking.dart`: server response models and Dhaka travel dates
- `lib/services/student_api.dart`: existing API adapter, session/Origin, errors
- `lib/state/booking_state.dart`: selection, submit guard, refresh, cancellation
- `lib/screens/student/student_booking.dart`: dashboard, trips, review, history, details
- `lib/widgets/seat_map.dart`: server-driven eligibility and selected visual state
- `lib/widgets/booking_summary.dart`: receipt and real-ticket integration boundary
- `lib/theme/student_theme.dart`: Material theme
- `lib/student_booking.dart`: public exports
- `lib/main.dart`: authenticated host integration widget
- `test/booking_test.dart`: state and widget regression cases
- `test/student_api_test.dart`: HTTP contract and backend-error tests
- `pubspec.yaml`, `pubspec.lock`, `.gitignore`: Flutter package setup

## Validation

Run `flutter pub get`, `flutter analyze`, and `flutter test` in this directory.
Tests use an injected fake API and never connect to Neon or modify the backend.
Real authentication, Android device testing, real QR decoding and server fare
verification require the missing host and QR/fare source contracts.

### Verified in this session

- Flutter 3.47.9 / Dart 3.13.7, installed in a temporary directory.
- Dependency resolution passed; `pubspec.lock` records resolved versions.
- Flutter analyze: no issues found.
- Flutter test: **15 passed, 0 failed**. Covers eligibility, selected visual state,
  standing payload, review, closed windows before/after review, backend rejection,
  successful booking, duplicate submission, uncertain network outcome, server history
  after state recreation, details, cancellation, ticket removal and HTTP contracts.
- QR tests validate renderer gating/removal using an injected test widget; they do
  **not** validate a real QR implementation or QR decoding.
- Tests use fake services or a local HTTP server, not the real backend/database.
- The shell launcher stalled while initializing, so analysis/tests used Flutter's
  own CLI entrypoint directly via the downloaded SDK's Dart executable, with
  `--no-version-check --suppress-analytics`. Analysis required cache access and the
  Flutter test runner required local socket access.
- No Android APK build/device test, real-session walkthrough, real QR test or fare
  verification was possible with the supplied checkout. No commit or push.
