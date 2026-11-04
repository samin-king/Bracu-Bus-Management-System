# BRACU Bus Management System

<<<<<<< HEAD
The integrated API starts in `services/src/server.js`. It retains Member 1's verified email/session authentication and Member 2's student APIs, and mounts Member 3/4's transport modules from `server/src`. `server/src/index.js` delegates to the same authenticated entry point.

## Local use

1. Install dependencies with `npm install`.
2. Configure a private `.env` using `.env.example`; supply a random session secret and the existing database credentials.
3. Run `npm run migrate` against the intended application database. This is required before using the integrated transport features.
4. Run `npm run dev` and, in another terminal, `npm run dev --workspace transport-client`.

Student pages include dashboard, profile, booking, history, complaints, feedback and notifications. Students can save Male/Female in [Student Profile](docs/student-gender-profile.md); booking reads the saved gender and verification status from the database. Registered drivers automatically land at `/driver` using the same login form and session; see [driver role login](docs/driver-role-login.md). `/transport` retains bus, route, trip, driver and authority complaint screens. Management mutations require an authority/admin session. Driver controls require a verified account linked by `users.driver_id`. Account roles and driver links are assigned by trusted administration, never browser input.

For immediate local student/registered-staff login, see [local direct login](docs/local-direct-login.md). This requires explicit `DEV_DIRECT_LOGIN=true`, development mode and loopback-only access; production continues to verify email links.

Email sign-in uses existing accounts and one-time links. SMTP settings enable real delivery. The explicit loopback-only `DEV_EMAIL_LOGIN=true` mechanism remains available for the registered local test student; see `docs/local-student-login.md`. Existing optional Google endpoints remain compatible, but email sign-in does not require Google credentials.

## Vercel deployment

The frontend and integrated Express API deploy together from the repository root.
Use [the Vercel deployment guide](docs/demo-deployment.md) for the root configuration,
required DATABASE_URL/SESSION_SECRET, build-time migrations and optional email delivery.
No separate backend service or demo seed is required to start the API.

## Database

All migrations are tracked under lowercase `database/migrations` for Windows/Linux compatibility. Both migration commands use the same transactional runner and migration ledger. The order is authentication, fleet/trips, drivers, email tokens, student booking/complaints, Member 4 extensions, then integration constraints. `003_member4.sql` extends the existing complaints table; it does not create a second complaint system. Member 2's API retains its existing status vocabulary while authority updates and notifications share those records.

Booking uses scheduled database trips at its four supported departure times; other departures remain visible in transport management. Standing capacity defaults to zero and can be configured through the authority Buses form in the existing `buses.standing_capacity` column. Female reservation and standing use trusted server-side profile gender; see [booking priority and standing](docs/booking-priority-standing.md) for the local verification profiles and results. Existing booking snapshots and legacy string trip identifiers remain valid.

## Verification

- `npm test`: authentication, booking, fleet, driver, complaint, notification and queue unit/integration tests.
- `npm run build`: production frontend bundle.
- `npm run test:frontend`: React tests and built-frontend API tests (build first).
- `TEST_DATABASE_URL` enables disposable-schema PostgreSQL checks, including independent-connection booking races.
- `TEST_REDIS_URL` enables the optional live Redis queue test.

The existing BullMQ queue infrastructure is preserved. Its standalone worker still requires an injected `processBooking` implementation; the original worker does not process student bookings by itself. Student bookings use the tested synchronous authenticated API. No new public queue submission endpoint is introduced.
=======
Existing React frontend: `Client/`. Existing Express transport API: `server/`.
Schema and seeds: `Database/`. See existing Member 3 documentation for
[bus/route/trip](docs/member3-part1-bus-route-trip.md),
[drivers](docs/member3-part2-driver.md), and
[Redis/queues](docs/member3-part3-redis-queue-worker.md).
The nested `Bracu-Bus-Management-System/` contains separate existing Member 1 work;
this contribution does not change it.

# Member 3 — Flutter Contribution

## Responsibilities

- Bus Management: list, API-backed details, add/edit, registration, capacity and status.
- Route Management: list, API-backed details, add/edit, origin, destination and ordered stops.
- Trip Management: list, API-backed details, add/edit supported fields, Dhaka departures, joined bus/route/driver information and status.
- Driver Management: list, API-backed details, add/edit, license and active/inactive status.
- Driver Assignment: scheduled trips, active drivers, change/unassign, returned assignment and errors.
- Assigned Trips: verified driver's own trips, schedule, route, bus, status and timestamps.
- Passenger List: navigation and explicit unavailable screen only; no passenger data endpoint exists.
- Trip Start/Stop: backend-controlled SCHEDULED → ACTIVE → COMPLETED, pending controls, success and error feedback.
- Flutter API integration: Dart services/models, current session credentials per request, HTTP errors, timeouts and response validation.

Screens use SafeArea, scrollable mobile lists/forms, loading, empty, retry and
error states. Shared RecordCard renders each model's details. Trip forms load
actual buses/routes. Assigned trip status uses driver controls; assigned
active/historical schedules are locked. Backend validation, ownership checks,
database constraints and booking-window rules are unchanged.

## Flutter Files

All listed files are new; this workspace had no existing Flutter project.

Entry point and screens:

- `flutter_app/lib/main.dart`
- `flutter_app/lib/screens/bus/bus_screen.dart`
- `flutter_app/lib/screens/routes/route_screen.dart`
- `flutter_app/lib/screens/trips/trip_screen.dart`
- `flutter_app/lib/screens/driver/driver_screen.dart`
- `flutter_app/lib/screens/driver/driver_assignment_screen.dart`
- `flutter_app/lib/screens/driver/driver_dashboard.dart`
- `flutter_app/lib/screens/driver/passenger_list_screen.dart`
- `flutter_app/lib/screens/management_screen.dart`
- `flutter_app/lib/screens/record_form.dart`

Services:

- `flutter_app/lib/services/api_client.dart`
- `flutter_app/lib/services/resource_service.dart`
- `flutter_app/lib/services/bus_service.dart`
- `flutter_app/lib/services/route_service.dart`
- `flutter_app/lib/services/trip_service.dart`
- `flutter_app/lib/services/driver_service.dart`

Models:

- `flutter_app/lib/models/transport_record.dart`
- `flutter_app/lib/models/bus.dart`
- `flutter_app/lib/models/route.dart`
- `flutter_app/lib/models/trip.dart`
- `flutter_app/lib/models/driver.dart`

Widgets and tests:

- `flutter_app/lib/widgets/async_body.dart`
- `flutter_app/lib/widgets/record_card.dart`
- `flutter_app/lib/widgets/role_gate.dart`
- `flutter_app/test/transport_test.dart`

Project configuration: `flutter_app/pubspec.yaml`, `flutter_app/pubspec.lock`,
`flutter_app/analysis_options.yaml`, `flutter_app/.gitignore`,
`flutter_app/.metadata`, `flutter_app/README.md` and the generated Android runner
under `flutter_app/android/` (Gradle configuration, Kotlin MainActivity, manifests,
wrapper properties, launcher icons and launch resources/styles).
The main manifest adds Internet permission; only the debug manifest permits
cleartext HTTP. Build, SDK, cache and local IDE files are ignored.

## Existing APIs Reused

Routes are mounted by `server/src/app.js`. Lists return arrays, details/save
return objects, and errors use `{"error":"message"}`.

| Backend route file | Existing endpoints used | Purpose |
| --- | --- | --- |
| `server/src/routes/busRoutes.js` | GET/POST `/api/buses`, GET/PUT `/api/buses/:id` | Bus list/detail/create/edit |
| `server/src/routes/routeRoutes.js` | GET/POST `/api/routes`, GET/PUT `/api/routes/:id` | Route list/detail/create/edit with stops |
| `server/src/routes/tripRoutes.js` | GET/POST `/api/trips`, GET/PUT `/api/trips/:id` | Trip list/detail/create/edit with joined bus/route/driver |
| `server/src/routes/driverRoutes.js` | GET/POST `/api/drivers`, GET/PUT `/api/drivers/:id` | Management driver list/detail/create/edit |
| `server/src/routes/driverRoutes.js` | GET `/api/drivers/me`, GET `/api/drivers/me/trips` | Authenticated driver profile and own trips |
| `server/src/routes/tripRoutes.js` | PUT `/api/trips/:id/driver` | Assignment/change/unassign with `driver_id` or null |
| `server/src/routes/tripRoutes.js` | POST `/api/trips/:id/start`, POST `/api/trips/:id/stop` | Assigned authenticated driver controls, no identity in body |

No duplicate endpoints or DELETE requests were introduced; none of these routers
supports deletion. Route stops are entered one per line to preserve commas in
names. Empty stops are valid. Generic trip payloads exclude `driver_id`;
assignment uses only the dedicated endpoint.

## Backend Reused

Flutter only communicates with the existing Express backend, which retains the
PostgreSQL/Neon database and the existing Bus service
(`server/src/services/busService.js`), Route service (`routeService.js`), Trip
service (`tripService.js`), shared `resourceService.js`, Driver service
(`driverService.js`), controllers and `server/src/middleware/driverIdentity.js`.
The existing migrations `Database/migrations/001_bus_route_trip.sql`,
`002_driver.sql` and seeds `Database/seeds/development.sql`, `drivers.sql` are
unchanged. Database credentials stay server-side.

## Driver Features

Dashboard loads `/drivers/me` and `/drivers/me/trips`. Assigned-trip cards show
bus capacity, route/stops, Dhaka schedule, status, and start/completion timestamps.
Active drivers can start scheduled trips and stop active trips. Stop returns
COMPLETED, matching the existing backend. Controls disable during requests;
errors preserve the previous state. Refresh reloads authoritative data after
conflicts/external changes. Status changes only from successful API responses.

Authority assignment filters scheduled trips and active drivers, supports
unassignment, and shows the returned trip. The backend retains schedule,
ownership, inactive-driver and state-transition checks. Passenger navigation
opens an explicit unavailable screen without making an invented API call.
Actual passenger records and booking integration are not implemented.

## Authentication and Authorization Integration

Standalone launch starts signed out. The mounted transport backend has no login
endpoint, and Member 1's separate authentication project is not connected to it.
The parent authentication app must supply `TransportApp(session: verifiedSession)`
after login. Example inside that app's authenticated branch:

```dart
final verifiedSession = TransportSession(
  role: TransportRole.driver, // map from the server-verified account role
  headers: () async => {'Authorization': 'Bearer ${await auth.currentAccessToken()}'},
);
return TransportApp(session: verifiedSession, baseUrl: 'https://your-api.example/api');
```

`auth.currentAccessToken()` represents the host application's token provider;
this contribution does not define it or claim the transport backend already
verifies Bearer tokens. Supply the authenticated Cookie header instead if the
integrated server uses sessions. Native HTTP does not automatically share browser
cookies. Replace/dispose the transport session/app on logout or account change;
navigation resets for a new session object. Never use a client role picker or
arbitrary driver ID as authentication.

Route gates and service guards deny Students transport management and Driver
features. Drivers cannot access Authority management. These checks supplement
server checks; they cannot establish server security.

**Existing backend limitation:** bus/route/trip management routers currently lack
role authorization middleware. Driver management/assignment use the supplied
`authorizeManagement` hook (denies access by default). Driver controls require
`req.auth.driver_id` and ownership checks. Production needs Member 1/4's verified
authentication integration and Authority authorization on all management routes.
No backend files were changed, per task scope. Flutter tests prove client access
restrictions, not protection against direct HTTP calls to unguarded management
endpoints. End-to-end production login and Authority RBAC are not complete.

## Android Setup

Validated with Flutter 3.47.9 / Dart 3.13.7 on Windows. Minimum declared versions:
Flutter 3.35 / Dart 3.9; only the stated validation version was tested.
Install an Android SDK and configure `ANDROID_HOME` for Android builds.
From `flutter_app/`:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

`10.0.2.2` addresses the host from the standard Android emulator. Physical devices
need the host's reachable LAN address and backend port. Release builds need HTTPS
and normal release signing; generated Gradle retains Flutter's debug signing
placeholder. No Android GPS permissions are requested.

Start the existing backend with its configured database as described in
`docs/member3-part2-driver.md`. No migration/seed changes are needed. The existing
opt-in server-side development identity is not production authentication and is
not enabled or forged by Flutter. The standalone app stays signed out until
the host's verified authentication flow supplies a session.

## Redis / Queue

Redis/BullMQ remains backend infrastructure. Jobs, workers, retries and error
handling stay server-side. Flutter implements no Redis, BullMQ, queue workers or
booking rules, and calls no invented queue endpoints.

## Live Tracking

Live GPS tracking is not currently implemented.

The tracking files under `services/src/routes/` are empty placeholders and are
not mounted in the transport app. No fake positions or simulator was added.

## Testing

`flutter_app/test/transport_test.dart` covers bus list/detail/create/edit,
validation/loading/empty/error/retry; route/trip/driver list/detail; dashboard and
assigned trips; assignment success/error; credentials and payloads; start/stop
responses, pending controls and inactive driver; empty assignments; unavailable
passenger navigation; direct screen/service authorization; signed-out navigation;
malformed responses and backend 401/403/409; 320×640 phone layout.
HTTP mocks verify Flutter contracts and UI, not real-device integration or
production server RBAC.

- `flutter analyze`: **passed, no issues found** (Flutter 3.47.9 / Dart 3.13.7).
- `flutter test`: **28 passed, 0 failed**.
- Existing `npm test`: **57 passed, 0 failed, 1 skipped**; real Redis integration requires `TEST_REDIS_URL`.
- `flutter build apk --debug`: attempted; **blocked: No Android SDK found**. No APK/device/emulator verification is claimed.

## Contribution Summary

Member 3 implemented Flutter Transport and Driver modules while reusing the
existing Express APIs and PostgreSQL database. The contribution covers Bus,
Route, Trip, Driver, Driver Assignment, Assigned Trips and Trip Start/Stop, plus
an unavailable Passenger List screen. Passenger data, deletion, live GPS and
end-to-end production authentication/Authority RBAC remain unavailable in the
inspected backend integration.

## Change Inventory

Created: **51 files**: root `README.md`, 24 Dart library files, 1 Flutter test file,
19 Android runner files and 6 Flutter project/documentation/configuration files.
Existing tracked files modified: none. Existing tracked files deleted:
none. Backend, React, database and other members' work are unchanged. Flutter SDK
was downloaded to ignored `.local/flutter` for verification; SDK/build caches
are excluded from the contribution. No commit or push was performed.
>>>>>>> origin/flutter-member3-transport
