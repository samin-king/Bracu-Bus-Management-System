# Flutter verification — 16 November 2026

The actual application runs in Chrome. Android execution is blocked by the
absence of an Android SDK, emulator sources, and connected Android device.
The supplied Flutter 3.47.9 SDK was used exclusively by absolute path.
No global PATH changes, SDK upgrades, migrations, seeds, commits, or branch
changes were performed.

## View the results

- Screenshot gallery: http://127.0.0.1:8188/gallery.html
- Actual standalone build: http://127.0.0.1:8188/standalone/
- Interactive fixture management screens: http://127.0.0.1:8188/
- Interactive fixture driver dashboard: http://127.0.0.1:8188/?role=driver
- Live local management reads: http://127.0.0.1:8188/?live=true
- Live local driver reads: http://127.0.0.1:8188/?live=true&role=driver
- Fixture state examples: append `?state=loading`, `?state=empty`, or
  `?state=error`, then open Buses.

The standalone app starts signed out. There is no connected login flow.
The separate demo entry point supplies a demonstration session; it is never
imported by the production entry point. Live mode uses the backend's already
configured local development identity, not verified user authentication.
The local visual server only proxies GET requests; live writes were not tested.
Do not deploy the demonstration entry point as a production login flow.

## Results

- `flutter doctor -v`: Flutter and Chrome available; Android SDK absent;
  Windows C++ desktop build components incomplete; Flutter not globally on PATH.
- `flutter pub get`: passed. Four newer dependency versions are outside the
  current constraints; no upgrades made.
- `flutter analyze`: passed with no issues, including the demo entry point.
- `flutter test`: all 28 passed.
- `npm.cmd test`: 57 passed, zero failed, one real Redis integration test skipped.
- Both standalone and visual-demo web builds succeeded.
- Browser navigation and screenshots: all six requested modules rendered,
  including live local data; no browser page exceptions recorded.
- Fixture browser interactions: Start Trip and Stop Trip completed with the
  expected UI notices; loading, empty and error states captured.
- Existing Flutter tests additionally verify create/edit validation, assignment
  success/failure, retry recovery, permissions, pending controls and conflicts.
- Live GET endpoints returned 200: buses (3), routes (2), trips (18), drivers (2),
  driver profile and driver assigned trips (8).

Screenshots and machine-readable capture results are under
`../.local/flutter-screenshots/`. Each image labels fixture data or live local
development data. The standalone screenshot is `standalone-verified.png`.

## Changes and local services

Added `web/index.html` to make browser execution possible without Android.
Added `tool/visual_demo.dart` to exercise the existing production widgets and
services with fixture responses or read-only local API data. No production Dart
code needed fixing. Flutter automatically added the web directory to analyzer
exclusions during the build; this does not change app behavior.

Local helper scripts in ignored `.local/` serve the compiled builds, proxy
read-only API traffic, capture screenshots with the existing Playwright install,
and generate the gallery. They do not modify application records.

Windows refused PostgreSQL's bind to port 5432 (permission denied). The existing
database was started on temporary loopback port 55432 using command-line options.
Express runs on port 3000 with a process-only database URL port override; `.env`
was not edited. The visual server runs on loopback port 8188.

For later sessions, rebuild with the absolute Flutter executable from this
directory: `build web --target tool/visual_demo.dart --output build/visual-demo`
and `build web --output build/standalone`. Start the visual helper from the
repository root with `node .local/flutter-visual-server.cjs`. Its standalone
subpath requires the generated standalone index base href `/standalone/`.
The gallery generator is `node .local/flutter-gallery.cjs`.

## Remaining limitations

Android validation requires installing Android SDK/platform tools and an AVD
or connecting a USB-debug-enabled device, then running the supplied SDK with
`run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api` for a standard emulator.
Physical devices need a reachable host URL or ADB port forwarding.

Production authentication and server authorization integration remain incomplete.
The frontend's session and role guards do not establish server-side security.
Passenger records have no backend endpoint; that screen correctly explains the
limitation. Live GPS tracking is absent. Redis was not started or live-tested.
The web compiler emitted a nonfatal Cupertino font warning; visible inspected
screens rendered correctly.
