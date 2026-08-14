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

Run unit tests by specifying the name of an installed iPhone simulator:

```sh
xcodebuild \
  -project Dutypark.xcodeproj \
  -scheme Dutypark \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
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

After switching the Xcode Development Team and Bundle ID, a generic iOS Release build with development signing succeeded. The provisioning profile's application identifier, Sign in with Apple `Default` entitlement, and Associated Domains entitlement were verified. Creating an App Store distribution-signed archive, running Validate App, and completing TestFlight verification remain outstanding. When releasing under an individual membership, the account holder's legal name may appear as the App Store seller name.
