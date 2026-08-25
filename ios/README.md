# Dutypark iOS

Dutypark is an iPhone-only SwiftUI app. The native client follows the web/PWA's
five-tab product structure while owning its own session, cache, outbox, and
offline recovery behavior.

## Requirements

- Xcode 26 or later
- iOS 17 or later
- Swift 6

## Offline behavior

Offline support is currently native-iOS functionality; it is not the same as
the web PWA service worker. The web worker handles push presentation,
notification-click routing, badges, and locale data, but does not cache the
app shell or arbitrary fetch responses. The native app can reopen a recently
verified regular account for up to 30 days when the API is unavailable.

### Local storage and reads

Account-scoped data is stored in Application Support under:

```text
Dutypark/Offline/accounts/<memberID>/
```

The cache contains a reduced profile snapshot (including friends and D-Days),
monthly calendar snapshots (calendar cells, schedules, duties, Korean holidays,
and compared-member duties), and the Todo board. OAuth provider identifiers and
access/refresh tokens are not written to the cache. Calendar prefetch maintains
a rolling thirteen-month window: the current month plus six months on either
side. Cached values are snapshots and may be stale until the next successful
online refresh.

When offline, Calendar and Todo can render their cached data. Home, Social,
Team, and Notifications are online-only at the root level. Cached detail views
remain read-only where a mutation would require the server.

### Offline writes and synchronization

Only these new, plain creates can be persisted while offline:

- schedules with content/title, description, visibility, and start/end times;
- Todos with title, content, status, and due date.

Tags, attachments, AI time parsing, edits, deletes, duty changes, D-Day
changes, friend/team actions, and notification operations require a connection.
Each queued create receives a local UUID operation ID. The ID identifies the
local outbox entry only; it is not sent as an API idempotency header. On the
server, duplicate creates are suppressed by content: schedule owner + content +
description + start/end time, and Todo owner + effective status + title +
content. Schedule visibility and Todo due date are intentionally excluded from
that identity.

The outbox stores `pending` and `permanentFailure` entries with attempt count,
last failure, and the next retry time. Recovery drains entries in creation
order. Transport/decoding failures and HTTP 408, 425, 429, and 5xx responses
use exponential backoff from five seconds up to five minutes. Validation and
permission 4xx responses become permanent failures and require an explicit
retry; 401 handling belongs to `SessionStore` and the authentication boundary.
Logging out or switching accounts purges that account's cache and outbox, and
authentication-generation guards prevent in-flight work from crossing into a
different account. Offline mode does not provide conflict-free update/delete
sync; the server is authoritative after recovery.

The implementation lives in `Dutypark/Core/Offline/` and is covered by focused
unit tests in `DutyparkTests` (cache, outbox, session fallback, and sync
coordinator behavior).

## Opening and Verification

Open `Dutypark.xcodeproj` in Xcode, or use the following command:

```sh
xcodebuild \
  -project Dutypark.xcodeproj \
  -scheme Dutypark \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  build
```

By default, run only the `DutyparkTests` unit test target by specifying the name of an installed iPhone simulator. The `-only-testing` option prevents the scheme's UI test target from running:

```sh
xcodebuild \
  -project Dutypark.xcodeproj \
  -scheme Dutypark \
  -destination 'platform=iOS Simulator,name=iPhone 13 mini' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:DutyparkTests \
  test
```

### TestFlight Upload

After logging into the Apple Developer account in Xcode (`Xcode > Settings > Accounts`), run the local release script from the repository root:

```sh
./ios/scripts/upload-testflight.sh
```

The script reads the app marketing version from the Xcode project, generates a
KST `YYYYMMDD` build number, creates a Release archive, exports it with App
Store distribution signing, and submits it to App Store Connect. Release-note
metadata keeps its separate `YYYY.MM.DD` changelog version format. Artifacts
are written under `ios/build/testflight/`, which is ignored by Git.

The command succeeding means that the transport accepted the upload; it does
not mean that App Store Connect has finished processing or validation. Check
the build's processing state and TestFlight availability in App Store Connect
before calling a release verified. The same marketing version/build number
cannot be uploaded twice: use an explicitly increasing `BUILD_NUMBER` for a
second run on the same day. The script also refuses to overwrite an existing
archive or export path, so preserve the paths for investigation or choose a
new build/path when retrying.

For a command preview without archiving or uploading:

```sh
DRY_RUN=1 ./ios/scripts/upload-testflight.sh
```

Set `BUILD_NUMBER` to override the generated build number, for example
`BUILD_NUMBER=20260826.1` for another upload on the same day. Set
`MARKETING_VERSION` to override the Xcode project's marketing version for a
one-off build. App Store Connect processing continues asynchronously after the
upload command succeeds.

### Screenshots and demo captures

Use a local, marker-owned demo account and local backend data for captures;
never use production credentials or production data as a screenshot fixture.
Populate the current Asia/Seoul date, a full calendar month, Todo statuses,
friends, tags/notifications, duties, and a future D-Day before capturing. Upload
profile photos through the authenticated profile-photo flow before generating
tag/friend events so notification actor snapshots carry the same photo version.

Korean and English capture runs use separate local demo datasets; the harness
logs out first and signs in with the owner account for the selected locale.

Keep raw app captures separate from App Store compositions. Produce Korean and
English sets independently, and keep UI text/data in the real app capture.
Image-generation tools may add only a restrained outer marketing canvas,
mascot, or decorative sticker; they must not redraw or translate UI text,
icons, status bars, or data. Store repository assets under
`docs/screenshots/readme/` for the README gallery. Keep App Store raw captures,
generated artwork, and final Korean/English deliverables under
`docs/app-store/{raw,generated,final}/`; see
[`docs/app-store/README.md`](../docs/app-store/README.md). The current 6.9-inch
portrait reference is `1320x2868`; verify all final dimensions against Apple's
[Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
and [upload guidance](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/).

### UI Tests (Explicit Request Only)

Do not run `DutyparkUITests` during default verification, even when an iOS UI change affects an existing UI test. Run a specific UI test or the full UI test target only when the user explicitly requests it.

To run a requested test class or method, use its Xcode test identifier:

```sh
xcodebuild \
  -project Dutypark.xcodeproj \
  -scheme Dutypark \
  -destination 'platform=iOS Simulator,name=iPhone 13 mini' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:DutyparkUITests/TestClassName/testMethodName \
  test
```

To run the full UI test target when the user explicitly requests a full UI test run:

```sh
xcodebuild \
  -project Dutypark.xcodeproj \
  -scheme Dutypark \
  -destination 'platform=iOS Simulator,name=iPhone 13 mini' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:DutyparkUITests \
  test
```

## Project Structure

- `Dutypark/App`: App entry point and root navigation
- `Dutypark/Core`: Shared app infrastructure
- `Dutypark/Domain`: Shared domain types
- `Dutypark/Features`: Screen-specific features
- `Dutypark/Components`: Shared SwiftUI components
- `Dutypark/Resources`: String Catalog and future app assets
- `Dutypark/Config`: Build environment configuration
- `DutyparkTests`: Unit tests
- `DutyparkUITests`: UI tests

The Xcode project uses filesystem-synchronized groups. In most cases, adding files to the source directories above does not require changes to `project.pbxproj`.

## Signing Status

The individual Apple Developer Program membership was approved on 2026-08-14. The Team ID is `2V47G42CDS`, and the bundle identifier in the Xcode project is set to the registered Explicit App ID `io.github.shanepark.dutypark`. The Sign in with Apple, Push Notifications, and Associated Domains capabilities are enabled.

After switching the Xcode Development Team and Bundle ID, a generic iOS Release build with development signing succeeded. A distribution export and App Store Connect transport upload were verified on 2026-08-22 using the local Xcode account. That archive record confirms upload acceptance only; verify App Store Connect processing/validation and TestFlight availability separately before release. When releasing under an individual membership, the account holder's legal name may appear as the App Store seller name.
