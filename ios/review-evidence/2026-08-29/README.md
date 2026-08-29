# App Store review evidence — 2026-08-29

This directory keeps a compact, version-controlled record of the verification cited by
`ios/APP_STORE_REVIEW_AUDIT_2026-08-29.md`. It contains no credentials, webhook URLs,
private keys, account data, or test-user secrets.

## Source state

- Repository HEAD during the backend/web/iOS unit rerun was
  `3d55d46de011f8a18b8b38434836b8fe8acb3a31`, with the then-uncommitted
  account-deletion retention disclosure that was later committed as `1856c2aa`.
- Repository HEAD during the App Store screenshot refresh was
  `1856c2aaccfe086d6828366a0a7291363a43a1d7`, with the screenshot harness,
  Team month accessibility metadata, local demo seed, images, and evidence documents
  still uncommitted.
- The distribution Archive and exported IPA were produced from clean repository HEAD
  `268029a3265e7f2ef1096df81b75353a2c489f5c`.
- These are development verification records, not clean-commit attestations. Before
  submission, repeat the relevant checks from a fixed commit and retain the raw artifacts.

## Backend, web, and iOS unit rerun

| Scope | Command | Result | Durable evidence |
|---|---|---|---|
| Backend full test | `env JAVA_HOME=/Users/shane/.sdkman/candidates/java/17.0.18-tem PATH=/Users/shane/.sdkman/candidates/java/17.0.18-tem/bin:$PATH GRADLE_USER_HOME=/tmp/dutypark-gradle-account-deletion ./gradlew test` | PASS; 1,845 total, 1,824 PASS, 21 SKIP, 0 FAIL/ERROR | Gradle XML aggregation recorded in `verification-summary.json`; source XML was `build/test-results/test/TEST-*.xml` |
| Web full test | `cd frontend && npm test` | 97 files PASS; 727 tests PASS | `verification-summary.json` |
| Web type check | `cd frontend && npm run type-check` | PASS | `verification-summary.json` |
| Web production build | `cd frontend && npm run build` | PASS; 2,218 modules transformed | `verification-summary.json` |
| iOS unit tests | `cd ios && xcodebuild -project Dutypark.xcodeproj -scheme Dutypark -destination 'platform=iOS Simulator,name=iPhone 13 mini' -derivedDataPath /private/tmp/dutypark-retention-postadmin-derived CODE_SIGNING_ALLOWED=NO -resultBundlePath /private/tmp/dutypark-retention-postadmin-20260829.xcresult -only-testing:DutyparkTests test` | PASS; 1,126 identifiers: 1,125 aggregate PASS, 1 SKIP, 0 FAIL; 1,150 expanded PASS | `xcresulttool` summary and bundle provenance recorded below and in `verification-summary.json` |

The fresh iOS run used `iPhone 13 mini`, iOS Simulator 26.5 (23F77). The one skipped
test was
`OfflineSessionStoreTests/testSnapshotAndDirectoryUseFirstUnlockFileProtection()`.
The finalized `xcresulttool get test-results summary` reports 1,126 identifiers,
1,125 aggregate PASS, 1 SKIP, and 0 FAIL. Its device/configuration expansion reports
1,150 PASS and 1 SKIP.

The full fresh iOS bundle remains temporary because it is 11 MB:

- Path: `/private/tmp/dutypark-retention-postadmin-20260829.xcresult`
- Finalized: `2026-08-29T21:02:35+0900`
- Deterministic tree SHA-256: `088fa2fa3f2c5befe0bc370dea5c25178be69bc2940778d9e29b6c92ea7954f1`

The tree hash is the SHA-256 of the sorted list of each relative file path and file
SHA-256. It identifies the local bundle while it exists; it is not a substitute for
retaining that bundle in CI or release artifact storage.

It was generated from the finalized bundle with:

```sh
find /private/tmp/dutypark-retention-postadmin-20260829.xcresult -type f -print0 \
  | sort -z \
  | xargs -0 shasum -a 256 \
  | sed 's#  /private/tmp/dutypark-retention-postadmin-20260829.xcresult/#  #' \
  | shasum -a 256
```

The focused unit bundles cited by the audit were also checked read-only:

| Artifact | Result | Size | Finalized | Deterministic tree SHA-256 |
|---|---|---:|---|---|
| `/private/tmp/dutypark-focused-contentfilter-20260829.xcresult` | 11 identifiers / 11 runs PASS | 776 KB | `2026-08-29T15:05:48+0900` | `cfc63a0d27bcc1e33a3fbad399acdbdf0bcd0cb3a90779bb954bada7d7b8411b` |
| `/private/tmp/dutypark-focused-calendar-20260829.xcresult` | 104 identifiers / 104 runs PASS | 1.6 MB | `2026-08-29T15:05:48+0900` | `6cea9d33d38dc62e6ea3318c5ed4dbc9bb8497fb624a17ba82c0387e48f163fc` |
| `/private/tmp/dutypark-focused-team-20260829.xcresult` | 55 identifiers / 56 expanded runs PASS | 1.1 MB | `2026-08-29T15:05:48+0900` | `3410f6c16e21c47c4a7d2b4e61ef460690c814047fbd2876245dadc339bac6d0` |

## Historical iOS UI evidence

The full UI suite was not rerun for this documentation change. Repository policy makes
full UI runs opt-in. The following pre-existing bundles support the historical baseline
and focused RED→GREEN statements, but their original commands and exact dirty-tree
state were not captured. They must not be represented as clean-commit attestations.

| Artifact | Result | Size | Finalized | Deterministic tree SHA-256 |
|---|---|---:|---|---|
| `/private/tmp/dutypark-ui-full-13mini-20260829.xcresult` | 91 total: 89 PASS, 2 selector/accessibility lookup FAIL | 154 MB | `2026-08-29T11:30:07+0900` | `316887e8b073e8b60afe1a7d379850d07f3246fe6d29531cfe774dcc7ae52580` |
| `/private/tmp/dutypark-ui-account-green-20260829.xcresult` | Account deletion focused test `Success` | 2.0 MB | `2026-08-29T11:40:54+0900` | `33233435c1a7e87f3473d2ea6d03a35e0f9afeaf5719d1b161e315874c8665b2` |
| `/private/tmp/dutypark-ui-account-fallback-green-20260829.xcresult` | Account deletion fallback focused test `Success` | 2.1 MB | `2026-08-29T13:27:01+0900` | `49e1128df9ea45a3cabd032342343b1ef647e9f3c0a4228447c60c18474c75c3` |
| `/private/tmp/dutypark-ui-notification-green-20260829-final.xcresult` | Notification close focused test `Success` | 1.4 MB | `2026-08-29T12:39:49+0900` | `50fba816d2e68f89b5fd7878541438ee2953380b220b9345203b5e2fca46da91` |

The baseline failures were:

- `AccountDeletionParityUITests/testFinalDestructiveActionMatchesResponsiveWebWithoutExecutingDeletion()` — `XCTAssertTrue failed`
- `NotificationConfirmationVisualUITests/testClosingLoadedDropdownMarksUnreadNotificationsAsRead()` — `XCTAssertTrue failed`

Each account-deletion focused bundle has three destination/configuration rows marked
`Success` and one `TestCaseRuns` row marked `Success`. The notification focused bundle
has the same three `Success` destination/configuration rows and one successful run row.

## App Store screenshot refresh

The stale 2026-08-26 screenshots were replaced from a real local demo-account run
against an isolated loopback backend using `dutypark_demo`. The user's existing 8080
backend and 5173 web server were not restarted or modified.

```sh
xcodebuild -project ios/Dutypark.xcodeproj \
  -scheme Dutypark \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -derivedDataPath /private/tmp/dutypark-appstore-capture-8081-derived \
  CODE_SIGNING_ALLOWED=NO \
  API_BASE_URL=http://localhost:8081/api/ \
  -resultBundlePath /private/tmp/dutypark-appstore-capture-final3-20260829.xcresult \
  -only-testing:DutyparkUITests/DemoAppStoreCaptureUITests test
```

- Result: PASS, 2 total / 2 PASS / 0 FAIL / 0 SKIP.
- Device: iPhone 17 Pro Max, iOS Simulator 26.5 (23F77), arm64,
  `2AFDB0DF-841A-433F-B923-9241B21E58CB`.
- Result bundle: `/private/tmp/dutypark-appstore-capture-final3-20260829.xcresult`,
  65 MB, finalized `2026-08-29T22:50:29+0900`.
- Deterministic tree SHA-256:
  `88bb141117dcee80d749d359e1dd207193bcad60b13857de5434c81a654a7fd1`.
- Output: 14 opaque 1320x2868 raw PNGs and 12 opaque 1320x2868 composed PNGs.
- Pipeline tests: `scripts/test-extract-app-store-captures.sh` PASS and
  `scripts/test-compose-app-store-screenshots.sh` PASS.
- Visual review: all 14 raw and 12 final images PASS. The English Calendar, Team,
  and D-Day use November 2026 and contain no Korean public-holiday labels. No login or
  error screen, credential, secret, or real personal data is visible.

The checked-in raw and final PNG files are durable evidence of the visible result. The
`.xcresult` path remains temporary and must be uploaded to retained artifact storage if
the test-run provenance itself is needed after local cleanup.

Because the screenshot fix adds Team month accessibility metadata to app code, the full
`DutyparkTests` suite was rerun afterward on the exact `iPhone 13 mini`:

- Result: PASS; 1,126 identifiers, 1,125 aggregate PASS, 1 SKIP, 0 FAIL;
  device-expanded 1,150 PASS and 1 SKIP.
- Bundle: `/private/tmp/dutypark-appstore-final-unit-20260829.xcresult`, 11 MB,
  finalized `2026-08-29T22:56:47+0900`.
- Deterministic tree SHA-256:
  `7cb530b8b4dc426bda3d1702b8404e39f1525ceee19bb1cae1954c0ca8672304`.
- The verified Debug app was installed on exact simulator
  `F0737016-7654-4967-83FA-1DFB951DB36E`; `simctl get_app_container` confirmed the
  installed `io.github.shanepark.dutypark` bundle.

## Release simulator capture

The canonical temporary launch capture cited by the audit is:

- Path: `/private/tmp/dutypark-release-latest-20260829.png`
- Size: 297,562 bytes; PNG 1080×2340 RGBA
- Finalized: `2026-08-29T13:04:55+0900`
- SHA-256: `f832da0f055d5441f6d41c5ad300242a50105e3432d3f5b561a075c1589a9313`

This is simulator smoke evidence only. It is neither an App Store screenshot nor proof
of distribution signing, production entitlements, or an exported IPA.

## App Store distribution Archive and IPA

A Release device Archive and a local `app-store-connect` export were produced without
uploading to App Store Connect:

```sh
xcodebuild -project ios/Dutypark.xcodeproj -scheme Dutypark \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/dutypark-appstore-final-derived \
  -archivePath /private/tmp/dutypark-appstore-final-20260829.xcarchive \
  MARKETING_VERSION=1.0.0 CURRENT_PROJECT_VERSION=1 \
  DEVELOPMENT_TEAM=2V47G42CDS CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates archive
xcodebuild -exportArchive \
  -archivePath /private/tmp/dutypark-appstore-final-20260829.xcarchive \
  -exportPath /private/tmp/dutypark-appstore-final-export-20260829 \
  -exportOptionsPlist /private/tmp/dutypark-testflight-export/ExportOptions.plist \
  -allowProvisioningUpdates
```

- Archive: PASS; Release, generic iOS device, arm64, clean source HEAD above.
- Export: PASS; `/private/tmp/dutypark-appstore-final-export-20260829/Dutypark.ipa`.
- IPA SHA-256:
  `851993f3d51ef89da63015c8a0f3bd797b5c4ef55256e76201f1688abdb13352`.
- `codesign --verify --deep --strict`: PASS; Apple Distribution certificate class,
  expected team and bundle identifier.
- The signed-app entitlement and embedded App Store profile both contain the production
  APNs environment; `get-task-allow` is disabled.
- The exported app uses `iphoneos26.5`, version `1.0.0` build `1`, the production API
  URL, the expected associated domain, Sign in with Apple entitlement, `dutypark` URL
  scheme, camera purpose string, and a bundled `PrivacyInfo.xcprivacy`.

The Archive, IPA, distribution logs, and extracted inspection directory are temporary
local artifacts. The SHA and summarized checks are durable here, but the IPA itself
must be retained in release artifact storage if this exact binary will be submitted.

## Remaining retention gate

This compact record resolves the missing command/result/SHA linkage for the fresh
backend, web, and iOS unit reruns and preserves the known UI artifact provenance. Full
`.xcresult` bundles, the Archive, IPA, and raw logs are still in `/private/tmp` and are
not durable. Before the audit HOLD can be released, the final submission artifacts and
real-device evidence must be uploaded to retained CI or release artifact storage, then
temporary paths here must be replaced with stable artifact links and checksums.
