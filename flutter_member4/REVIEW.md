# Member 4 integration review

Reviewed on 9 November 2026. All changes are confined to `flutter_member4/`.
Flutter execution is blocked by the missing SDK; this is a source review and
remediation report, not a compilation or Android acceptance certification.

## Findings addressed

| Finding | Resolution |
|---|---|
| Session state keyed to an InheritedWidget instance | A required host `sessionKey`, stable API and role define the state boundary. Ordinary rebuilds preserve drafts; account/permission changes discard state. |
| Notification dialog retained content after sign-out | Dialog subscribes to the session and hides its snapshot after account/API changes or sign-out. |
| Missing session caused a null assertion | A descriptive FlutterError explains that the session must wrap the Navigator. |
| Reusing a detail screen with a different ID could retain old data | Detail page has a key containing complaint ID and management mode. |
| Raw casts could fail during widget building | Models validate consumed fields; API rejects malformed arrays, objects, records and unread counts with controlled errors. |
| JSON without a charset could corrupt Bangla text | Response bytes are decoded as UTF-8. |
| Send and response-body phases had separate timeouts | One configurable overall timeout bounds the request; writes are never automatically retried. |
| Caller-supplied IDs could form unexpected URLs | IDs and pagination bounds are checked before transport. Base URLs require HTTP(S), a trailing slash, and no embedded credentials/query/fragment. |
| Submission and list requests could overlap, dropping the post-submit reload | Initial reads, mutations, refresh and paging are mutually gated in the UI/state. |
| Failed saves hid the form | Mutation errors preserve records and editable drafts; only authentication/permission errors hide feature data. |
| Retry could reload the wrong page | Failed reads retain the requested page offset. Successful navigation scrolls to the page start. |
| Successful writes followed by failed refresh could be misunderstood | Success remains visible alongside the read error; Retry performs a GET rather than replaying the write. |
| Management resubmitted unchanged status/response | Only changed fields are PATCHed; unchanged saves make no request; blank responses preserve the existing response. |
| Detail pages showed irrelevant pagination | Detail views disable pagination. |
| Error/confirmation at the top could remain offscreen | Mutations and failed loads reveal their message by scrolling to the top. |
| Clearing a submitted complaint could immediately show validation errors | Successful complaint submission resets form interaction/validation state. |
| Long content and large text could crowd layouts | Preview text is capped; detail text remains complete; safe areas, a maximum content width, expanded dropdowns, wrapping page controls and scrollable details are shared. |
| Status/read state was difficult to scan | Theme-based status chips, icons, typography and explicit read/unread labels distinguish state without relying solely on color. |

## API comparison

Read-only comparison used `member4Routes.js`, `member4Controller.js`,
`member4Access.js`, `member4Validation.js`, and the existing complaint, feedback
and notification services. Backend files were not changed or executed in this
review. The package uses only the twelve existing method/path combinations.

* Student complaint bodies contain category, description, optional trip_id and
  route_id. No owner/status/response/role claims are submitted.
* Authority/admin PATCH bodies contain changed status and/or nonempty response.
  All four backend statuses are supported without invented workflow transitions.
* Feedback bodies contain target, integer rating 1–5, optional comment and only
  the selected target's reference. Whitespace-only comments fail validation.
* Lists are plain JSON arrays with limit=50 and offset=page*50. Complaint
  management uses existing status/category/search filters.
* Notification unread-count consumes `{count: integer}`. Read actions use PATCH.
  Details use the list record; there is no GET notification-by-ID request.
* The host-provided HTTP client's `send` method supplies real authentication.
  Production code creates no login, token, identity header or role header.
* Server 401/403 remains authoritative. Local roles only gate feature screens.

Categories, statuses, target names, raw text lengths and positive 32-bit IDs match
the backend validators. Record IDs may be numeric or strings. Foreign-key
existence and ownership remain server responsibilities.

## Files changed

* `pubspec.yaml`: declared minimum Flutter version consistent with Dart 3.4.
* `lib/models/member4_models.dart`: response validation.
* `lib/services/member4_api.dart`: safe response decoding, parsing, bounds and timeout.
* `lib/state/member4_session.dart`: explicit account/session boundary.
* `lib/widgets/member4_widgets.dart`: guards, request states, shared presentation,
  status chips, responsive layout and pagination.
* All five screen files: complaints, complaint management, complaint detail,
  feedback and notifications.
* Both test files: updated UI assertions and additional regression coverage.
* `README.md`, `VERIFICATION.md`: current integration and verification guidance.
* `REVIEW.md`: this review report.

`lib/member4.dart` and `.gitignore` were inspected and required no changes.
There are no changes to existing backend, database or other feature files.

## Integration prerequisites

1. Supply the existing authenticated HTTP client and API URL ending in `/api/`.
2. Supply the verified role/authenticated state and required stable `sessionKey`.
   Change the key on logout/account changes, even if reusing the client.
3. Place Member4Session above the root/feature Navigators so pushed pages and
   notification dialogs receive updates. The host owns client disposal.
4. Run dependency resolution, formatting, Flutter analysis and tests with the
   host SDK before merging. See VERIFICATION.md for the commands and blockers.
5. Test the integrated application with real student, authority/admin and other
   authenticated accounts on Android. Check sign-out with open details, small
   screens, larger text, network failures, paging and refresh.

Unsupported functionality remains excluded: complaint audit timelines/threads,
attachments/deletion, feedback editing/deletion, notification unread reversal,
notification detail APIs, public notification sending, live streaming and device
push. No substitute backend behavior has been introduced.
