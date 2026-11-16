# BRACU transport schedule integration

## Implementation status and source

The existing Flutter booking package and Express booking service now use a normalized PostgreSQL transport catalog. The source is the Desktop screenshot effective **3 October 2026**, archived at `docs/sources/bracu-transport-2026-10-03.png`. The complete row-by-row comparison is in [transport-schedule-extraction.md](transport-schedule-extraction.md), and the machine-readable extraction is `database/seeds/bracu-2026-10-03.json`.

**This is not a completed, fully verified official import.** Five staged schedules remain unverified: four Bashundhara schedules because the screenshot crops its heading, plus the duplicate evening Jigatola-A 17:15 row. The cover's “eleven routes” disagrees with twelve variant identities. No label is silently changed to Jigatola-B. The missing table headings and closure/holiday calendar still need transport-office confirmation. All seeded schedules are initially **inactive**, with **no invented buses, capacities, drivers or coordinates**.

The implementation was exercised using disposable embedded PostgreSQL and Flutter tests. No configured local/Neon/production database migration or seed has been applied by this task. The previously audited local database authentication problem must be resolved before applying the migration. A real authenticated Android walkthrough and measured 20,000-request/minute load test remain unverified.

## Data and migration

Migration `database/migrations/003_transport_schedule.sql` adds:

- `transport_sources`: image fingerprint, effective date, outstanding source issues.
- `transport_routes`, `transport_variants`: eight route groups and twelve independent variant identities.
- `transport_stops`, `transport_patterns`, `transport_pattern_stops`: reusable stop records and independent inbound/outbound ordered associations. The original printed label belongs to each association; matching names differing only in case/whitespace deduplicate without merging distinct landmarks.
- `transport_schedules`, `transport_stop_times`: effective dates, service days, first pickup/departure and separate arrival times, verification/activation, assignments and per-stop pickup/arrival values.
- `transport_buses`, `transport_drivers`, `transport_gps_devices`: real operational assignments and optional unique bus-to-device mapping, with no simulated tracking.
- `transport_service_exceptions`: administrator-maintained closure dates.
- `transport_admins`, `transport_audit`: explicit grants for existing authenticated identities and attributable administrative changes.
- Nullable booking foreign keys `schedule_id`, `pickup_stop_id`, `dropoff_stop_id`. Legacy rows keep null references and unchanged JSON snapshots.

The SQL adds foreign keys, bounded coordinates/capacities, time/date/day checks, uniqueness, ordered-stop constraints and lookup indexes. Seed version/fingerprint and a transaction advisory lock make repeat imports a no-op. Reimporting the same version cannot overwrite admin changes. A changed fingerprint under the same version fails rather than overwriting data. A later official revision requires an explicit migration/import strategy; this is not an automatic arbitrary-version merger.

### Missing information is retained as missing

There is no second morning trip for Abdullahpur-B, Jigatola-B or Narayanganj, and no afternoon departure for those three variants. Outbound rows specify a BRAC University departure and destination label but do **not** give a stop sequence. Each outbound pattern therefore contains only the documented campus pickup, sets `sequence_verified=false` and exposes no invented drop-off selection. It does not reverse the inbound list.

Inbound campus entries are arrival-only/drop-off associations, never pickup times. Pickup/drop-off IDs in the booking API are **pattern-stop association IDs**, not unrestricted global stop IDs. The API enforces route/trip membership, pickup eligibility and ordered supported drop-offs.

Service days follow the explicit Saturday–Thursday range. The source also says “excluding weekends”; the exact interpretation and government holidays/semester breaks/online-class/maintenance closure dates must be confirmed and entered by administrators. An admin can deactivate an affected unbooked service. No public-holiday dates are guessed.

## Run the updated backend

Use a development/disposable PostgreSQL database first. Preserve the existing `.env`; do not replace a configured environment with the example.

```sh
npm ci
# Create .env from .env.example only if it does not already exist.
# Configure DATABASE_URL, SESSION_SECRET, existing Google OAuth and FRONTEND_URL.
npm run migrate
npm run seed:transport
npm run dev:server
```

`npm run migrate` uses the existing ledger/transaction runner. `npm run seed:transport` checks the archived image hash, inserts the version once, prints that verification is incomplete, and leaves all assignments/trips inactive. The server now checks that the transport migration exists at startup.

PostgreSQL is the default catalog. `TRANSPORT_CATALOG=legacy-json` is an explicit compatibility/testing fallback to the old `MEMBER2_TRIPS_JSON` adapter; it does not populate the normalized route catalog and is not the deployment configuration for this feature. No old booking API is replaced or duplicated.

### Administrator provisioning and operations

There is no public self-promotion endpoint. A trusted database owner grants an **existing authenticated account**, after approval, for example:

```sql
-- Replace this example address with the approved, already-created account.
INSERT INTO transport_admins(user_id)
SELECT id FROM users WHERE email = 'approved.admin@g.bracu.ac.bd'
ON CONFLICT (user_id) DO NOTHING;
```

No grant was applied to an actual account by this implementation. Existing OAuth eligibility remains unchanged; this does not add a staff-email OAuth realm or driver login. Driver records are operational assignment profiles. Reopen the app after a new grant so the admin entry can reload access; every backend admin request rechecks the grant regardless of UI state.

In the Flutter dashboard, **Transport administration** appears only after a successful backend access check. Administrators can browse routes, edit stop labels and verified coordinates, reorder stops, create/update schedules and all pickup/arrival times, select service days/effective dates, assign actual buses/drivers, activate/deactivate trips, register actual device identifiers and manage closures. Buses, drivers, devices, schedules and closures use bounded pages, with Previous/Next controls and paginated assignment pickers.

Unverified schedules require an official confirmation reference when marked verified. An unverified variant also needs a separate referenced confirmation. Activation requires a verified variant/schedule and active real bus/driver assignments. Overlapping bus/driver assignments are rejected. An unknown outbound arrival conservatively reserves that assignment through the rest of the day; provide an approved operational end time before reusing that assignment later that day.

Changing a schedule, its stops/order or assigned bus/driver while it has future confirmed bookings returns `schedule_in_use`. This intentionally prevents silent ticket/capacity changes. Reordering an unbooked pattern deactivates its schedules until their new time ordering is reviewed; activation checks every association and timing. Use a new operational schedule/version or the existing authorized cancellation process to reconcile bookings rather than editing them behind students' backs. Calendar closures block new candidates; they do not automatically cancel existing bookings.

## Flutter integration and use

The repository still provides an **embeddable Flutter module**, not a standalone authenticated Android host. The existing authentication owner must supply the real `HttpStudentApi` session-cookie callback and configured origin. No cookie, Google credential or schedule is hardcoded into Flutter. The new screens use the existing Material theme and `BookingState`; no new runtime package is added.

```dart
import 'package:bracu_student_booking/main.dart';
import 'package:bracu_student_booking/student_booking.dart';

// In the application's existing authenticated host:
Widget studentModule(HttpStudentApi authenticatedApi) =>
    StudentBookingApp(api: authenticatedApi);
```

`BookingState` automatically composes `HttpTransportApi` when supplied the existing `HttpStudentApi`. Tests/custom hosts may inject a separate `TransportApi`. API base URL, native INTERNET permission, HTTPS and session acquisition remain host responsibilities. This task does not add a fake login or claim that `flutter run` can launch the package without that host.

From `flutter_student/`:

```sh
flutter pub get
flutter analyze
flutter test
```

Flutter 3.47+ / Dart 3.13+ are explicitly required, matching the SDK used for verification.

Student flow:

1. Open **Bus Routes & Stoppages**; browse route/variant and inbound/outbound direction.
2. Search stops; inspect first/second pickup columns and distinct university arrival values. Unverified entries and missing outbound drop-offs are explained.
3. Open **Book Bus**, choose route/direction and date, then an assigned active trip. Published but unassigned/inactive source schedules remain visible in stop information, not offered as bookable seats.
4. Select a valid pickup, supported drop-off and eligible seat/standing option, review, then confirm with the existing POST endpoint.
5. History/details display the confirmed snapshot: route/variant, direction, bus/trip/date, selected stops, pickup time and seat. Historical text does not change after schedule edits. QR remains conditional on the existing renderer hook; this repository has no real QR/fare implementation, so neither is fabricated.

Route/pattern screen futures are reused during searches/rebuilds and refreshed explicitly or when opened again. Backend metadata is no-store; no Redis or application route cache exists, so there is no stale server cache to invalidate after admin commits. Booking always revalidates against PostgreSQL inside its existing transaction.

## API changes

All routes use existing authenticated sessions. Mutations require the configured Origin and JSON. Admin requests additionally require a `transport_admins` grant and are limited to 240 requests/minute per process/IP. Request bodies are bounded to 64 KB. Existing `/api/student/bookings` stays the sole booking creation operation.

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/student/transport/routes` | Route/variant/direction/pattern inventory. |
| GET | `/api/student/transport/patterns/:id` | Ordered associations, coordinates if verified, and per-schedule pickup/arrival times. |
| GET | `/api/student/transport/schedules` | Paginated published schedules; optional variantId/date/direction filters. |
| GET | `/api/student/transport/sources` | Source fingerprint and unresolved extraction issues. |
| GET | `/api/student/transport/access` | Whether the authenticated identity has an admin grant. |
| GET | `/api/transport-admin/routes`, `/patterns/:id`, `/schedules`, `/sources` | Authorized catalog inspection. |
| GET/POST | `/api/transport-admin/resources/:kind` | Page/create buses, drivers, devices or exceptions. |
| PUT | `/api/transport-admin/resources/:kind/:id` | Update a bus/driver/device. Closures are upserted by date via POST. |
| DELETE | `/api/transport-admin/exceptions/:date` | Remove an entered closure. |
| PUT | `/api/transport-admin/stops/:id` | Edit an association label and verified coordinates/reference. |
| PUT | `/api/transport-admin/patterns/:id/order` | Reorder the exact existing association ID set atomically. |
| POST/PUT | `/api/transport-admin/schedules[/:id]` | Create/update timing, validity, verification and assignments. |
| PUT | `/api/transport-admin/variants/:id/verification` | Record referenced manual source confirmation. |
| GET | Existing `/api/student/trips` and `/trips/:id/seats` | Now use assigned, active, verified, calendar-valid DB schedules in default mode. |
| POST | Existing `/api/student/bookings` | Adds pickupStopId/dropoffStopId for normalized trips, preserving legacy payloads for the explicit legacy catalog. |

Trip responses retain `id`, `bus`, `route`, `departureTime`, `capacity`, `standingCapacity`, window metadata and seat eligibility. New metadata includes schedule/pattern/variant identity, direction, separate arrival time and allowed timed stop associations. New trip IDs use `schedule:<id>`; old text trip IDs and historical snapshots are unchanged.

### Booking and update safety

Existing user locks, per-trip/date advisory locks, unique confirmed-seat/student-trip indexes, standing eligibility/capacity, daily limits and cancellation rules remain in the same service. DB-catalog confirmation takes a shared transport configuration transaction lock and re-reads the schedule; admin changes take the exclusive lock. This prevents an assignment/stop update from racing the snapshot/validation. Seat capacity is still for the whole trip; stop selection does not introduce seat reuse across segments or new fares.

For normalized schedules, `bookingPeriod` applies the existing policy opening/closing rules independently of official pickup/departure: morning 1 opens previous day 20:00 and morning 2 at 21:00, closing at the actual first departure; afternoon remains 10:50–11:15 and evening remains 15:20–15:40. Legacy departures retain the original literal time mapping exactly. Campus arrival is not used as departure or pickup. These are existing application policy windows, **not times extracted from the brochure**.

## Verification and practical limits

Actual final results are recorded below after execution. Tests use controlled profile/assignment fixtures and disposable PGlite; those fixture buses/drivers are not official production assignments. Independent-connection PostgreSQL races require an explicitly disposable TEST_DATABASE_URL and remain skipped without it. No live database, Android device, real Google account or GPS hardware test is claimed.

Redis was not already present, so no Redis dependency was added. Queries use indexed FK relationships, bounded admin pagination and two batched catalog reads rather than per-trip database fetches. Booking remains atomic. The 20,000 requests/minute goal (~333 requests/sec) is a design target, **not a measured capacity result**; this change does not establish load-balancer, distributed-rate-limit or real-time tracking readiness.

The older PROJECT_IMPLEMENTATION_AUDIT.md remains a dated pre-integration snapshot; this document describes the new implementation and does not retroactively change old audit test claims.

## Final route-level comparison / staged import inventory

| Variant | Ordered inbound rows | First pickup → arrival | Second pickup → arrival | Afternoon departures | Evening departures | Verification |
|---|---:|---|---|---|---|---|
| 01-A Abdullahpur | 9 | 06:40 → 07:30 | 08:30 → 10:40 | 14:05 | 17:10 | Visible rows compared |
| 01-B Abdullahpur | 15 | 06:20 → 07:40 | Not provided | Not provided | 17:15 | Visible rows compared |
| 02-A Mirpur | 14 | 06:20 → 07:30 | 08:20 → 10:20 | 14:05 | 17:10 | Visible rows compared |
| 02-B Mirpur | 8 | 06:35 → 07:30 | 08:35 → 10:30 | 14:05 | 17:10 | Visible rows compared |
| 03-A Jigatola | 6 | 06:35 → 07:30 | 08:40 → 10:30 | 14:05 | 17:10, 17:15 (unverified duplicate) | 17:15 label unresolved |
| 03-B Jigatola | 6 | 07:40 → 08:45 | Not provided | Not provided | Not provided | Visible rows compared |
| 04 Azimpur | 10 | 06:25 → 07:30 | 08:30 → 10:45 | 14:05 | 17:10 | Visible rows compared |
| 05 Baldha Garden | 12 | 06:30 → 07:40 | 08:30 → 10:30 | 14:10 | 17:15 | Visible rows compared |
| 06-A Mohammadpur | 8 | 06:30 → 07:35 | 08:40 → 10:45 | 14:10 | 17:10 | Visible rows compared |
| 06-B Mohammadpur | 7 | 06:35 → 07:30 | 08:30 → 10:30 | 14:05 | 17:15 | Visible rows compared |
| 07 Narayanganj | 8 | 06:30 → 07:35 | Not provided | Not provided | 17:10 | Visible rows compared |
| 08 Bashundhara | 4 | 07:00 → 07:40 | 09:00 → 10:35 | 14:05 | 17:10 | Cropped header: confirmation required |

## Files created and changed by this integration

Pre-existing unrelated working-tree changes are not included here.

### Created (18 files)

- `database/migrations/003_transport_schedule.sql`
- `database/seeds/bracu-2026-10-03.json`
- `docs/sources/bracu-transport-2026-10-03.png`
- `docs/transport-schedule-extraction.md`
- `docs/transport-schedule-integration.md`
- `services/scripts/seed-transport.js`
- `services/src/routes/transportRoutes.js`
- `services/src/services/transportCatalog.js`
- `services/src/services/transportSeed.js`
- `services/src/services/transportService.js`
- `services/src/services/transportValidation.js`
- `services/test/transport.test.js`
- `flutter_student/lib/models/transport.dart`
- `flutter_student/lib/services/transport_api.dart`
- `flutter_student/lib/screens/admin/transport_admin.dart`
- `flutter_student/lib/screens/student/bus_routes.dart`
- `flutter_student/lib/widgets/trip_stops.dart`
- `flutter_student/test/transport_test.dart`

### Modified (15 files)

- `.env.example`
- `package.json`
- `services/src/app.js`
- `services/src/server.js`
- `services/src/services/member2Service.js`
- `services/src/services/bookingRules.js`
- `flutter_student/README.md`
- `flutter_student/lib/models/booking.dart`
- `flutter_student/lib/screens/student/student_booking.dart`
- `flutter_student/lib/services/student_api.dart`
- `flutter_student/lib/state/booking_state.dart`
- `flutter_student/lib/student_booking.dart`
- `flutter_student/lib/widgets/booking_summary.dart`
- `flutter_student/pubspec.yaml`
- `flutter_student/test/student_api_test.dart`

## Actual verification results

- Full Node backend suite: **83 cases, 82 passed, 0 failed, 1 skipped**. Includes all original authentication/booking tests plus 10 new transport tests. The skipped case needs disposable multi-connection PostgreSQL, not an embedded engine.
- Final transport tests also cover the resource-kind whitelist and oversized/malformed identifier rejection.
- Flutter: **26 tests passed**, including the original booking/HTTP tests and new route/stoppage/stop-selection/receipt/admin-access/retry tests and authenticated admin-method/namespace checks.
- Flutter analyze: **no issues found** using Flutter 3.47.9 / Dart 3.13.7 from a temporary SDK. No new runtime dependency was installed into the application.
- Node syntax checks and Dart formatting were run; neither frontend nor backend tests use production data. Embedded tests serialize transactions, so they do not prove independent-connection MVCC behavior or production throughput.
- A current read-only check of the configured local development PostgreSQL connection returned **28P01 (authentication failure)** after retry outside the socket sandbox. No migration or seed was run against that database. Fix the approved local credentials/role configuration, then follow the run commands above.
- Initial widget tests exposed a Future-returning setState callback on retry/refresh; the callbacks were fixed and recovery regression tests now pass. Initial sandbox local-socket/download restrictions were retried with the required tool permissions.
- Real OAuth/Android-device walkthrough, live schema application, real bus/driver assignments, real QR decoding, GPS hardware integration and a 20,000-request/minute load test remain unverified. No commit, push, deployment or production-data change was performed.
