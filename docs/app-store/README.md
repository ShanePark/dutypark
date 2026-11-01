# App Store screenshot pipeline

This directory keeps the source captures, generated decorative artwork, and
localized App Store deliverables separate:

```text
docs/app-store/
├── raw/ko|en/       # real app captures; each input is 1320x2868 PNG
├── generated/       # ImageGen artwork only (stickers/backgrounds)
├── final/ko|en/     # deterministic, opaque 1320x2868 submission PNGs
└── manifests/       # locale-specific composition manifests
```

Run a locale from the repository root:

```sh
scripts/compose-app-store-screenshots.sh docs/app-store/manifests/ko.json
scripts/compose-app-store-screenshots.sh docs/app-store/manifests/en.json
```

The current submission set contains six screens per locale: Home, Calendar,
Todo, Team, Social, and D-Day. The checked-in manifests are
`manifests/ko.json` and `manifests/en.json`; their outputs are written to
`final/ko/01-home.png` through `06-dday.png` and the matching English paths.
`more.png` is retained as a raw capture for future selection but is not part of
the six-screen App Store set. Both localized final sets are current: the
English raw captures use the Emma Moon demo account and English sample data.
Its Calendar, Team, and D-Day screens select the holiday-free November 2026
fixture so the English submission set contains no Korean public-holiday labels.

Capture metadata for this refresh:

```text
Capture date: 2026-11-02 (Asia/Seoul)
Device: iPhone 17 Pro Max
OS: iOS 27.0 (24A434)
App: 1.2.0 (20261102)
Canvas: 1320x2868 portrait, 8-bit RGB PNG without alpha
Account: isolated local dutypark_demo fixtures (Korean and English)
Source commit: 7cfd67d93a5a4d905b8cf10951ef95ba43312c73
Source state: capture harness-only modifications; production app UI unchanged
Capture API: http://localhost:8081/api/
Source: actual app capture, not generated UI; actual simulator clock
Final selected capture tests: Korean 1 PASS, English 1 PASS / 0 FAIL / 0 SKIP
Korean result: /private/tmp/dutypark-appstore-capture-20261102-v1.xcresult
English result: /private/tmp/dutypark-appstore-capture-20261102-en-v3.xcresult
Visual QA: all 12 final screenshots passed individual and contact-sheet review
```

The final Korean captures come from the Korean case in the initial two-case run;
its English images were superseded after visual QA found a notification prompt on
Home. The final English case captures Home only after the app's notification prompt
has been dismissed through its normal Cancel action. No screenshot pixels were
edited to remove UI. The English local demo schedule titles `Getaway` and
`Workshop` are short enough to show the real multi-day counters in the calendar.

Both locales use fictional November 2026 demo data, including a three-day personal
schedule crossing a D-Day, a three-day team schedule, and seven D-Day rows covering
future and past dates. The production App Review account is separate from these
local capture fixtures; its August 2026 data was not changed by this refresh.

The local capture data was prepared from a temporary copy of
`scripts/seed-local-demo-content.sh` at
`/private/tmp/dutypark-appstore-demo-20261102/seed-current-demo.sh`. August-derived
content used a +68-day offset from the `2026-08-26` origin for the actual
`2026-11-02` capture date, with the additional November personal/team spans and
seven D-Days described above. The unchanged checked-in seed retains its original
August defaults and does not by itself reproduce this refreshed dataset. Fixture
provenance is recorded in
`/private/tmp/dutypark-appstore-demo-20261102/provenance.json` and summarized in each
manifest's `capture.fixturePreparation` object.

Existing decorative artwork, fonts, headlines, and framing are unchanged. The full app viewport is preserved at one uniform scale. Recomposition from the
canonical raw files and manifests reproduces all 12 final PNGs byte-for-byte.

The same per-locale provenance is recorded in each checked-in manifest's
top-level `capture` object. The compositor ignores this metadata while keeping
it beside the exact inputs and localized copy that produced each final set.

`raw` is the source of truth. The compositor places every raw capture inside a
manifest-declared rounded device frame using one uniform scale. It never
non-uniformly scales, crops, or redraws the app UI. The manifest
must pass an aspect-ratio check, so the whole real screenshot remains visible.
Headlines and generated decorations may only be placed inside a
`safeArea` that does not overlap the device frame. A text or sticker frame that
falls outside that area is rejected. Referenced artwork is required: a missing
file fails the command instead of silently producing an incomplete submission.
All manifest rectangles use top-left coordinates, matching design-tool and
image-preview conventions. The current set uses Maplestory OTF Bold for concise
feature headlines and Maplestory OTF Light for supporting copy, with a clear
gap before the framed app capture.

The output is always an opaque 1320x2868 PNG with no alpha channel, suitable for
the iPhone 6.9-inch App Store slot. Keep the unmodified captures in `raw/` and
review the generated files in `final/` before uploading. Use the real UI capture for feature state;
ImageGen is limited to the outer decorative layer and must not recreate UI,
localized copy, status-bar content, or product data. The screenshot is scaled
only as a single rigid viewport inside the device frame; this is presentation
framing, not a replacement for a real app capture.

## Re-extracting raw captures from an xcresult

`DemoAppStoreCaptureUITests` keeps each real screenshot as an `XCTAttachment`
whose base name is `appstore-{locale}-01-home-demo` through
`appstore-{locale}-07-dday-demo`. Xcode's export manifest appends a repetition
and UUID suffix such as `_0_<UUID>.png`; the extractor normalizes that suffix
back to the base name while still rejecting duplicate base names. After an
explicitly requested UI-test run, point the Debug simulator build at the
isolated demo backend and then extract the attachments with the repository
script:

```sh
xcodebuild -project ios/Dutypark.xcodeproj \
  -scheme Dutypark \
  -destination 'platform=iOS Simulator,name=Dutypark App Store Capture — iPhone 17 Pro Max' \
  -derivedDataPath /tmp/dutypark-appstore-capture-derived \
  -resultBundlePath /tmp/dutypark-appstore-capture.xcresult \
  CODE_SIGNING_ALLOWED=NO \
  MARKETING_VERSION=1.2.0 CURRENT_PROJECT_VERSION=20261102 \
  API_BASE_URL='http://localhost:8081/api/' \
  -only-testing:DutyparkUITests/DemoAppStoreCaptureUITests test
scripts/extract-app-store-captures.sh \
  --result /tmp/dutypark-appstore-capture.xcresult \
  --locale ko \
  --force
scripts/extract-app-store-captures.sh \
  --result /tmp/dutypark-appstore-capture.xcresult \
  --locale en \
  --force
```

The script invokes `xcrun xcresulttool export attachments`, reads its generated
`manifest.json`, and maps the seven exact attachment names to
`raw/{ko,en}/{home,calendar,todo,team,more,social,dday}.png`. It validates every
file as a single 1320x2868 PNG without an alpha channel before staging the whole
set. Existing captures are never overwritten unless `--force` is explicit;
missing or duplicate expected attachment names, invalid dimensions/alpha, and
missing exported files fail without writing a partial set. `more.png` is kept
as a raw capture, while the checked-in six-screen manifests intentionally omit
it from the App Store submission set.

The example manifests are minimal one-screen compositions that use the current
raw captures and generated artwork. Copy one when starting a new locale or
layout, then replace its input, output, and localized copy. The local smoke test
checks the output dimensions, opaque pixels, safe-area text placement, and
explicit failure for missing generated assets:

```sh
scripts/test-compose-app-store-screenshots.sh
scripts/test-extract-app-store-captures.sh
```

The second test uses a fixture export to exercise the attachment-name mapping,
missing/duplicate handling, dimension/alpha checks, and the explicit overwrite
guard without touching the checked-in captures.
