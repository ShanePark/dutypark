# App Store review evidence — 2026-08-29

This directory keeps a compact, version-controlled record of the verification cited by
`ios/APP_STORE_REVIEW_AUDIT_2026-08-29.md`. It contains no credentials, webhook URLs,
private keys, account data, or test-user secrets.

## Source state

- Repository HEAD during the final rerun: `407f139799ed97aa873032c06fdc6c2a159438b3`.
- The verified source is the current uncommitted working tree on that HEAD, including
  the account-deletion receipt/status implementation, migration, client UI, and tests.
- This is a development verification record, not a clean-commit attestation. Before
  submission, repeat the same checks from a fixed commit and retain the raw artifacts.

## Fresh rerun bound to the source state above

| Scope | Command | Result | Durable evidence |
|---|---|---|---|
| Backend full test | `env JAVA_HOME=/Users/shane/.sdkman/candidates/java/17.0.18-tem PATH=/Users/shane/.sdkman/candidates/java/17.0.18-tem/bin:$PATH GRADLE_USER_HOME=/tmp/dutypark-gradle-account-deletion ./gradlew test` | PASS; 1,845 total, 1,824 PASS, 21 SKIP, 0 FAIL/ERROR | Gradle XML aggregation recorded in `verification-summary.json`; source XML was `build/test-results/test/TEST-*.xml` |
| Web full test | `cd frontend && npm test` | 97 files PASS; 725 tests PASS | `verification-summary.json` |
| Web type check | `cd frontend && npm run type-check` | PASS | `verification-summary.json` |
| Web production build | `cd frontend && npm run build` | PASS; 2,218 modules transformed | `verification-summary.json` |
| iOS unit tests | `cd ios && xcodebuild -project Dutypark.xcodeproj -scheme Dutypark -destination 'platform=iOS Simulator,name=iPhone 13 mini' -derivedDataPath /private/tmp/dutypark-commit-review-full-derived CODE_SIGNING_ALLOWED=NO -resultBundlePath /private/tmp/dutypark-commit-review-full-20260829.xcresult -only-testing:DutyparkTests test` | PASS; 1,168 identifiers: 1,167 aggregate PASS, 1 SKIP, 0 FAIL; 1,192 expanded PASS | `xcresulttool` summary and bundle provenance recorded below and in `verification-summary.json` |

The fresh iOS run used `iPhone 13 mini`, iOS Simulator 26.5 (23F77). The one skipped
test was
`OfflineSessionStoreTests/testSnapshotAndDirectoryUseFirstUnlockFileProtection()`.
The finalized `xcresulttool get test-results summary` reports 1,168 identifiers,
1,167 aggregate PASS, 1 SKIP, and 0 FAIL. Its device/configuration expansion reports
1,192 PASS and 1 SKIP.

The full fresh iOS bundle remains temporary because it is 60 MB:

- Path: `/private/tmp/dutypark-commit-review-full-20260829.xcresult`
- Finalized: `2026-08-29T17:49:13+0900`
- Deterministic tree SHA-256: `3b82fb2ae402bcc1226e85f8cf530aeb36838efd4883a914045276deb39975d7`

The tree hash is the SHA-256 of the sorted list of each relative file path and file
SHA-256. It identifies the local bundle while it exists; it is not a substitute for
retaining that bundle in CI or release artifact storage.

It was generated from the finalized bundle with:

```sh
find /private/tmp/dutypark-commit-review-full-20260829.xcresult -type f -print0 \
  | sort -z \
  | xargs -0 shasum -a 256 \
  | sed 's#  /private/tmp/dutypark-commit-review-full-20260829.xcresult/#  #' \
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

## Release simulator capture

The canonical temporary launch capture cited by the audit is:

- Path: `/private/tmp/dutypark-release-latest-20260829.png`
- Size: 297,562 bytes; PNG 1080×2340 RGBA
- Finalized: `2026-08-29T13:04:55+0900`
- SHA-256: `f832da0f055d5441f6d41c5ad300242a50105e3432d3f5b561a075c1589a9313`

This is simulator smoke evidence only. It is neither an App Store screenshot nor proof
of distribution signing, production entitlements, or an exported IPA.

## Remaining retention gate

This compact record resolves the missing command/result/SHA linkage for the fresh
backend, web, and iOS unit reruns and preserves the known UI artifact provenance. Full
`.xcresult` bundles and raw logs are still in `/private/tmp` and are not durable. Before
the audit HOLD can be released, final clean-SHA verification must upload the full logs,
`.xcresult`, Archive/export inspection, and real-device evidence to retained CI or
release artifact storage, then replace temporary paths here with stable artifact links
and checksums.
