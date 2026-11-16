# BRACU Transport — interactive Local Demo Mode

For the current navy/blue redesign and updated screenshots, see
[UI redesign report](UI_REDESIGN_REPORT.md). The walkthrough below still applies.

Open **http://127.0.0.1:8191/** and choose **Demo Student**, **Demo Driver**, or
**Demo Authority**. No Google account or password is needed for this mode.

Every screen displays **DEMO MODE**, the selected demo role, and
**Synthetic data · Local writes only · Not Google authenticated**.
The desktop side menu opens each module; narrow screens use a module dropdown.
Logout returns to Demo Login. Role changes retain the same demonstration data
within the tab. A full page reload resets it to the initial synthetic records.

## Student demonstration

- Dashboard: current fleet/schedule totals and your booking count.
- Student Profile: view synthetic identity and edit name/phone.
- Bus Booking: search routes/buses, inspect stops/date/capacity, reserve 1–4 seats.
  Duplicate confirmed reservations and over-capacity bookings are rejected.
- Booking History: view your reservations and cancel scheduled bookings.
- Complaints: add, view, edit and search your complaints; filter by status.
- Feedback: add/view/edit comments and a 1–5 rating, and search submissions.
- Notifications: read published messages for Students/All and mark them as read.

## Authority demonstration

Bus, Route, Trip and Driver Management reuse the existing production Flutter
list/detail/form/service/model widgets with an isolated in-memory client.

- Add records with the + button, search lists, view details and edit records.
- Filter buses, drivers and trips by status. Routes can be searched by names,
  origins, destinations and stops.
- Trip forms load actual records from the demo store for bus and route choices.
- Driver Assignment supports scheduled trips, active drivers, changes and unassignment.
- Complaints Management adds/views/edits/searches complaints and changes their
  status to OPEN, IN_REVIEW or RESOLVED.
- Notifications Management adds/views/edits/searches messages, chooses an audience,
  and changes DRAFT to PUBLISHED.

## Driver demonstration

- Driver Profile shows Karim Ahmed's synthetic profile and license.
- Assigned Trips reuses the existing Driver Dashboard, with route, bus, capacity,
  stops, departure and status information.
- Trip Schedule shows the same assigned schedule and transition timestamps.
- Passenger List displays synthetic passengers plus bookings created by Demo Student.
- Start Trip changes SCHEDULED → ACTIVE and records a start timestamp.
- Stop Trip changes ACTIVE → COMPLETED and records a completion timestamp.
- Trip cards show Dhaka timestamps; the schedule also shows the original UTC values.
- Ownership, inactive-driver and one-active-trip checks are simulated by the demo
  repository. They do not establish or bypass production authorization.

## Cross-role walkthrough

1. Demo Student → Bus Booking → Book trip #1 → Confirm booking.
2. Logout → Demo Driver → Passenger List. Ayesha Rahman's booking now appears.
3. Assigned Trips → Start Trip → Stop Trip. Inspect status and both timestamps.
4. Logout → Demo Authority → Driver Assignment. Select the 15:30 BRACU-01 trip,
   choose Karim Ahmed (Demo), and Save assignment.
5. Logout → Demo Driver. The additional trip appears in Assigned Trips / Trip Schedule.
6. Demo Student → submit a complaint. Demo Authority → search for it and edit
   its status to RESOLVED. Returning to Demo Student shows the updated status.
7. Demo Authority → add a notification, choose STUDENT audience and PUBLISHED.
   Demo Student → Notifications shows it and can mark it as read.

## Loading, empty, error and success states

Use the **Demo UI state** dropdown in the persistent yellow indicator:

- Normal restores the current module with data.
- Loading holds its data requests to demonstrate the spinner (existing service
  timeouts can still expire after 20 seconds). Choose Normal to release requests.
- Empty returns empty lists without deleting stored records.
- Error returns a clearly labeled demo error with retry controls.

Search for a nonexistent record for another empty-state example. Successful
forms, bookings, assignments and transitions show success feedback.

## Data isolation and authentication

All displayed data is synthetic. A read-only probe to the existing authenticated
backend returned 401, so no protected records were imported or authorization bypassed.

Demo transport requests go only to `MockClient`, backed by `DemoStore`, using
`https://local-demo.invalid/api`. No real network client is created for demo data;
the adapter also rejects any other host. All demo writes stay in browser memory.
The browser verification records whether any network `/api/` request occurs.

No PostgreSQL record, Google session, password, credential or production API is
used by Local Demo Mode. Booking, complaints, feedback, notifications and passenger
lists are synthetic demonstration implementations because those APIs are absent
from the authenticated transport backend. They are not completed production integrations.

The default entry point still runs real Google authentication. Demo mode requires
the explicit build flag below. Do not deploy a demo-flag build as the production app.

## Launch and checks

The SDK path with `.local` inside `D:\Bracubus` exists. The alternate
`D:\Bracubus.local\...` path supplied in the request does not exist.

From `D:\Bracubus\flutter_app`:

```powershell
& 'D:\Bracubus\.local\flutter\bin\flutter.bat' pub get
& 'D:\Bracubus\.local\flutter\bin\flutter.bat' analyze
& 'D:\Bracubus\.local\flutter\bin\flutter.bat' test
& 'D:\Bracubus\.local\flutter\bin\flutter.bat' run -d chrome --target lib/main.dart --web-hostname 127.0.0.1 --web-port 8191 --dart-define=LOCAL_DEMO=true
```

The Chrome-target command was run. Chrome-managed debug sessions on this machine
kept ending, so the persistent demonstration uses the equivalent real Flutter
web-server target and opens Chrome independently:

```powershell
& 'D:\Bracubus\.local\flutter\bin\flutter.bat' run -d web-server --target lib/main.dart --web-hostname 127.0.0.1 --web-port 8191 --dart-define=LOCAL_DEMO=true
```

This serves `lib/main.dart`, not the old fixture entry point or an HTML gallery.

## Verification results

- `flutter pub get`: passed.
- `flutter analyze`: passed, no issues.
- `flutter test`: **38 passed, 0 failed**.
- Actual Chrome workflow: all three role dashboards and every module visited.
- Bus/route/trip/driver Add, Edit, View and Search verified; bus status filtering
  and no-match searches verified; assignment saved and visible to the driver.
- Student booking appears in Driver passengers; an Authority-resolved complaint
  and targeted published notification appear for the Student.
- Driver Start/Stop verified with both timestamps and final COMPLETED status.
- Loading, empty, error, normal recovery and logout/role selection verified.
- Browser exceptions: **0**. Network API requests from the demo: **0**.
- **31 successful browser screenshots** captured. Existing failed-run diagnostic
  artifacts are not part of this report or its screenshot links.

## Screenshots of the actual interactive Flutter demo

These are browser captures of the demo application with its visible label.
They are not evidence of live backend authentication or production integration.

| Role | Module screenshot |
| --- | --- |
| Login | [Demo Login](../.local/complete-demo-screenshots/00-demo-login.png) |
| Student | [Dashboard](../.local/complete-demo-screenshots/01-student-dashboard.png) |
| Student | [Profile](../.local/complete-demo-screenshots/02-student-profile.png) |
| Student | [Booking](../.local/complete-demo-screenshots/03-student-bus-booking.png) |
| Student | [History](../.local/complete-demo-screenshots/04-student-booking-history.png) |
| Student | [Complaints](../.local/complete-demo-screenshots/05-student-complaints.png) |
| Student | [Feedback](../.local/complete-demo-screenshots/06-student-feedback.png) |
| Student | [Notifications](../.local/complete-demo-screenshots/07-student-notifications.png) |
| Authority | [Dashboard](../.local/complete-demo-screenshots/08-authority-dashboard.png) |
| Authority | [Buses](../.local/complete-demo-screenshots/09-authority-buses.png) |
| Authority | [Bus edit/detail](../.local/complete-demo-screenshots/10-authority-bus-edit-detail.png) |
| Authority | [Status filter](../.local/complete-demo-screenshots/11-authority-bus-filter.png) |
| Authority | [Routes](../.local/complete-demo-screenshots/12-authority-routes.png) |
| Authority | [Drivers](../.local/complete-demo-screenshots/13-authority-drivers.png) |
| Authority | [Trips](../.local/complete-demo-screenshots/14-authority-trips.png) |
| Authority | [Driver Assignment](../.local/complete-demo-screenshots/15-authority-driver-assignment.png) |
| Authority | [Assignment saved](../.local/complete-demo-screenshots/16-authority-assignment-saved.png) |
| Authority | [Complaints Management](../.local/complete-demo-screenshots/17-authority-complaints.png) |
| Authority | [Notifications Management](../.local/complete-demo-screenshots/18-authority-notifications.png) |
| Driver | [Dashboard](../.local/complete-demo-screenshots/19-driver-dashboard.png) |
| Driver | [Profile](../.local/complete-demo-screenshots/20-driver-profile.png) |
| Driver | [Assigned Trips](../.local/complete-demo-screenshots/21-driver-assigned-trips.png) |
| Driver | [Active trip](../.local/complete-demo-screenshots/22-driver-trip-active.png) |
| Driver | [Completed trip and timestamps](../.local/complete-demo-screenshots/23-driver-trip-completed.png) |
| Driver | [Schedule](../.local/complete-demo-screenshots/24-driver-schedule.png) |
| Driver | [Passengers](../.local/complete-demo-screenshots/25-driver-passengers.png) |
| Driver | [Notifications](../.local/complete-demo-screenshots/26-driver-notifications.png) |
| UI state | [Loading](../.local/complete-demo-screenshots/27-state-loading.png) |
| UI state | [Empty](../.local/complete-demo-screenshots/27-state-empty.png) |
| UI state | [Error](../.local/complete-demo-screenshots/27-state-error.png) |
| UI state | [Normal recovery](../.local/complete-demo-screenshots/28-normal-recovery.png) |

Machine-readable browser results and additional state screenshots are under
`.local/complete-demo-screenshots/verification.json`.
