# BRACU Transport UI redesign

The actual Flutter application is running at **http://127.0.0.1:8191/**. Choose Demo Student, Demo Driver or Demo Authority. All existing demo workflows remain functional.

## Design changes

- Shared deep navy / royal blue theme, soft blue-white surfaces, restrained gold accents and locally bundled Inter typography (Google Fonts, SIL Open Font License included).
- Centered role-selection card with icons, hover states, and a responsive university/bus illustration drawn in Flutter CustomPainter. No HTML replacement or screenshot-based UI.
- Navy desktop sidebar, active navigation indicators, role profile controls, logout, breadcrumbs and a compact module selector on mobile/tablet.
- Role-specific welcome areas, interactive overview metrics, quick actions, upcoming journeys and Student/Driver profile summaries. Every displayed count comes from the existing isolated demo store.
- Desktop management data tables with status badges and action controls; narrow screens retain readable cards. Search, filters, add/edit/detail forms and assignment logic are preserved.
- Consistent rounded information cards, styled forms, success notifications, loading indicators and polished empty/error/retry states.
- Lightweight hover, navigation highlight and page-fade animations.

## Verification

- flutter analyze: no issues.
- flutter test: **38 passed, 0 failed**. Desktop navigation tests now explicitly target sidebar ListTiles so dashboard shortcuts do not create ambiguous text matches.
- Full real-browser workflow: 14 checks passed across all three roles, with 31 module/state screenshots, 0 browser exceptions and 0 network API requests.
- Responsive browser checks: 30 role/module checks, 0 exceptions, at 320x740, 390x844, 768x1024 and 1024x768. Every module was visited at phone width.
- Add/Edit/View/Search/Filter, booking/history/profile editing, complaint resolution, notification publishing/read state, driver assignment, passenger sharing and SCHEDULED to ACTIVE to COMPLETED were exercised.
- The persistent actual Flutter web server remains on port 8191 and was opened in Chrome. The same lib/main.dart entry point and LOCAL_DEMO build flag are used.

## Data and scope

The redesign changes presentation, not authentication or storage. DEMO MODE remains visible on every screen. All demo data stays synthetic and in memory; full refresh resets it. No Google authentication was simulated, no production records were modified, and no backend permissions were bypassed. Shared styling also applies to the existing authenticated Flutter shell without altering its session handling.

The typography and illustration are bundled/code-native and need no runtime image-generation service. Production booking, notifications, passenger and complaint integrations remain outside this visual redesign.

## Screenshots

[Desktop login](../.local/premium-ui-screenshots/modules/00-demo-login.png) | [Authority dashboard](../.local/premium-ui-screenshots/modules/08-authority-dashboard.png) | [Student dashboard](../.local/premium-ui-screenshots/modules/01-student-dashboard.png) | [Driver dashboard](../.local/premium-ui-screenshots/modules/19-driver-dashboard.png)

[Phone login](../.local/premium-ui-screenshots/mobile-login.png) | [Phone dashboard](../.local/premium-ui-screenshots/mobile-student.png) | [Tablet dashboard](../.local/premium-ui-screenshots/tablet-authority.png) | [Laptop dashboard](../.local/premium-ui-screenshots/laptop-authority.png)

| Redesigned module / state | Genuine Flutter browser screenshot |
| --- | --- |
| demo login | [Open screenshot](../.local/premium-ui-screenshots/modules/00-demo-login.png) |
| student dashboard | [Open screenshot](../.local/premium-ui-screenshots/modules/01-student-dashboard.png) |
| student profile | [Open screenshot](../.local/premium-ui-screenshots/modules/02-student-profile.png) |
| student bus booking | [Open screenshot](../.local/premium-ui-screenshots/modules/03-student-bus-booking.png) |
| student booking history | [Open screenshot](../.local/premium-ui-screenshots/modules/04-student-booking-history.png) |
| student complaints | [Open screenshot](../.local/premium-ui-screenshots/modules/05-student-complaints.png) |
| student feedback | [Open screenshot](../.local/premium-ui-screenshots/modules/06-student-feedback.png) |
| student notifications | [Open screenshot](../.local/premium-ui-screenshots/modules/07-student-notifications.png) |
| authority dashboard | [Open screenshot](../.local/premium-ui-screenshots/modules/08-authority-dashboard.png) |
| authority buses | [Open screenshot](../.local/premium-ui-screenshots/modules/09-authority-buses.png) |
| authority bus edit detail | [Open screenshot](../.local/premium-ui-screenshots/modules/10-authority-bus-edit-detail.png) |
| authority bus filter | [Open screenshot](../.local/premium-ui-screenshots/modules/11-authority-bus-filter.png) |
| authority routes | [Open screenshot](../.local/premium-ui-screenshots/modules/12-authority-routes.png) |
| authority drivers | [Open screenshot](../.local/premium-ui-screenshots/modules/13-authority-drivers.png) |
| authority trips | [Open screenshot](../.local/premium-ui-screenshots/modules/14-authority-trips.png) |
| authority driver assignment | [Open screenshot](../.local/premium-ui-screenshots/modules/15-authority-driver-assignment.png) |
| authority assignment saved | [Open screenshot](../.local/premium-ui-screenshots/modules/16-authority-assignment-saved.png) |
| authority complaints | [Open screenshot](../.local/premium-ui-screenshots/modules/17-authority-complaints.png) |
| authority notifications | [Open screenshot](../.local/premium-ui-screenshots/modules/18-authority-notifications.png) |
| driver dashboard | [Open screenshot](../.local/premium-ui-screenshots/modules/19-driver-dashboard.png) |
| driver profile | [Open screenshot](../.local/premium-ui-screenshots/modules/20-driver-profile.png) |
| driver assigned trips | [Open screenshot](../.local/premium-ui-screenshots/modules/21-driver-assigned-trips.png) |
| driver trip active | [Open screenshot](../.local/premium-ui-screenshots/modules/22-driver-trip-active.png) |
| driver trip completed | [Open screenshot](../.local/premium-ui-screenshots/modules/23-driver-trip-completed.png) |
| driver schedule | [Open screenshot](../.local/premium-ui-screenshots/modules/24-driver-schedule.png) |
| driver passengers | [Open screenshot](../.local/premium-ui-screenshots/modules/25-driver-passengers.png) |
| driver notifications | [Open screenshot](../.local/premium-ui-screenshots/modules/26-driver-notifications.png) |
| state loading | [Open screenshot](../.local/premium-ui-screenshots/modules/27-state-loading.png) |
| state empty | [Open screenshot](../.local/premium-ui-screenshots/modules/27-state-empty.png) |
| state error | [Open screenshot](../.local/premium-ui-screenshots/modules/27-state-error.png) |
| normal recovery | [Open screenshot](../.local/premium-ui-screenshots/modules/28-normal-recovery.png) |

The machine-readable results are saved under `.local/premium-ui-screenshots/modules/verification.json` and `.local/premium-ui-screenshots/responsive-results.json`.
