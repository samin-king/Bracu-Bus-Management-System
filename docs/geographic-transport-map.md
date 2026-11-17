# Geographic university transport map

The web tracking page renders Leaflet/OpenStreetMap geography for BRAC University's Merul Badda campus and official schedule stops. The illustrative SVG and simulated bus animation are removed. GPS is not configured; no real-time bus location or traffic-aware ETA is shown.

## Sources and precision

Existing `/api/student/transport/routes` and `/patterns/:id` supply twelve inbound patterns. Shared stops and campus are deduplicated. Route filtering and search are local; there is no runtime geocoding or invented outbound itinerary.

`Client/src/data/transport-locations.json` covers all 107 timetable associations using 84 sourced reference groups. Of these, 46 are explicitly approximate area references; several labels can share a reference. Records preserve OpenStreetMap feature URLs and mapped feature names. The Merul Badda campus coordinate is 23.7733146, 90.4243710, from https://www.openstreetmap.org/way/1239676644. BRAC University's campus address is documented at https://www.bracu.ac.bd/student-life/brac-university-campus.

Landmark and area references are not surveyed boarding pins. The UI identifies approximate areas and displays the actual mapped reference and source. Existing administrator-supplied stop coordinates take precedence. Administrators can improve coordinates using the existing `/api/transport-admin/stops/:id` endpoint and coordinate-reference fields. Unknown new stops remain listed without an invented pin or distance. No schema or API changes are required.

Finite source preparation used low-rate, locally cached Photon/OSM candidate queries and manual rejection of unrelated matches. OSM attribution and ODbL licensing are retained. The app does not query geocoding providers.

## Distance and directions

Stop rows show haversine straight-line distance from campus using mean Earth radius 6371.0088 km. Area-reference estimates refer to the mapped area rather than an exact boarding point.

On request, an OSRM driving route supplies actual road geometry and estimated road length from campus to the selected reference. It may differ from the university bus itinerary and does not predict traffic or arrival time. Failed or malformed responses never produce a guessed road distance. Requests are queued at least 1.1 seconds apart per browser and successful destinations are cached for the page session. Late responses cannot overwrite a changed selection.

## Provider configuration

`VITE_MAP_TILE_URL` can override the default `https://tile.openstreetmap.org/{z}/{x}/{y}.png`. Attribution remains visible, normal browser caching is preserved, and only viewport tiles are loaded. See https://operations.osmfoundation.org/policies/tiles/.

`VITE_MAP_ROUTER_URL` can set an OSRM-compatible provider root. The low-volume local preview defaults to `https://router.project-osrm.org`. Its public demo permits reasonable non-commercial use, has a service-wide one-request-per-second limit and provides no availability guarantee. Larger deployments should configure an appropriate hosted/self-hosted provider; separate browser queues cannot guarantee a project-wide quota. See https://github.com/Project-OSRM/osrm-backend/wiki/Demo-server and https://project-osrm.org/docs/v5.24.0/api/.

Tile failures retain coordinates/distances with a reload action. Routing failures retain the straight-line estimate. A failed pattern does not hide routes that loaded successfully. No live database, booking rules or GPS services are changed.

## Verification

Tests cover all timetable associations, distance math, invalid/missing coordinates, administrator overrides, route filtering, search, partial metadata failures, road response parsing, caching and stale responses. Browser checks load real tiles and pins, request actual road directions, inspect mobile overflow and deliberately fail tiles to verify recovery.
