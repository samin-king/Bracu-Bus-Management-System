# Student schedule and stoppage booking on the web

The student Book a Seat page reads the imported official timetable. Students choose a travel date, direction, route variant, scheduled trip and pickup stoppage, then an eligible seat or standing ticket. Inbound trips show the published downstream campus arrival as the destination. Review shows the selected stoppage and its actual pickup time separately from the trip's first departure.

The page reads existing `/api/student/transport/routes`, `/patterns/:id` and paginated `/schedules` endpoints. Only trips also returned by `/api/student/trips` expose seat inventory and booking. Inactive, unassigned or unverified timetable entries remain visible as previews. Missing schedules, Friday closures and unpublished return stops are not filled in. If metadata fails, the page shows an error and retry. Existing installations without imported routes retain the original Member 3 booking page.

Confirmation rechecks `/api/student/trips/:id/seats` and then posts to the existing `/api/student/bookings`. It sends the actual `schedule:` trip ID, travel date, seat/standing and pattern-stop association IDs (`pickupStopId`, and `dropoffStopId` where supported). It sends no price, QR, student identity, capacity or booking-window override. Backend rules and database schema are unchanged.

Students can review a closed-window journey, but Confirm & Book is disabled. A synchronous submission guard prevents repeated requests. Seat conflicts and closed-window errors refresh availability. An ambiguous network failure after submission blocks further attempts on that page and directs students to Booking History. Booking confirmation, history and details render pickup and destination from the stored booking snapshot, including after cancellation or a page refresh.

## Local preview

The isolated local review database uses `TRANSPORT_CATALOG=postgres` to exclude development Member 3 trips. Its 37 source-verified schedules have explicitly local test bus/driver assignments and test capacities; the remaining five unverified entries are inactive. The local frontend process sets `VITE_LOCAL_SCHEDULE_PREVIEW=true` to identify this environment in the page. This flag only displays a label; it does not change eligibility, schedules or booking windows. These assignments are not production fleet data, and no live migration or activation is performed.

## Verification

React tests cover exact stop IDs/times, review-before-submit, seat and standing selection, missing pickup, closed windows, server revalidation, double submission, conflicts, uncertain responses, route/date resets, metadata failures, unavailable/unverified schedules and persisted booking snapshots. API tests cover authenticated requests, schedule pagination and backend error codes. Existing student, authentication and management frontend tests remain applicable.
