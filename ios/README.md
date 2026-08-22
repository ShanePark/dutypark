# Dutypark iOS

Dutypark is an iPhone-only SwiftUI app. Features are being migrated incrementally to native screens based on the web/PWA's five-tab structure.

## Requirements

- Xcode 26 or later
- iOS 17 or later
- Swift 6

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
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
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

The script reads the newest version from `src/main/resources/public-content/release-notes.json`, generates a unique timestamp build number, creates a Release archive, exports it with App Store distribution signing, and uploads it to App Store Connect. Artifacts are written under `ios/build/testflight/`, which is ignored by Git.

For a command preview without archiving or uploading:

```sh
DRY_RUN=1 ./ios/scripts/upload-testflight.sh
```

Set `BUILD_NUMBER` to override the generated build number. Set `MARKETING_VERSION` only when the newest release-note version is not a valid one-to-three-component App Store version. App Store Connect processing continues after the upload command succeeds.

### UI Tests (Explicit Request Only)

Do not run `DutyparkUITests` during default verification, even when an iOS UI change affects an existing UI test. Run a specific UI test or the full UI test target only when the user explicitly requests it.

To run a requested test class or method, use its Xcode test identifier:

```sh
xcodebuild \
  -project Dutypark.xcodeproj \
  -scheme Dutypark \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
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
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
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

After switching the Xcode Development Team and Bundle ID, a generic iOS Release build with development signing succeeded. A distribution export and App Store Connect upload were verified on 2026-08-22 using the local Xcode account. When releasing under an individual membership, the account holder's legal name may appear as the App Store seller name.
