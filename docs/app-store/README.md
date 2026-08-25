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
Its Calendar and D-Day screens select the holiday-free November 2026 fixture
so the English submission set contains no Korean public-holiday labels.

Capture metadata for this refresh:

```text
Capture date: 2026-08-26 (Asia/Seoul)
Device: iPhone 17 Pro Max
OS: iOS 26.5
App: 1.0.0 (1)
Canvas: 1320x2868 portrait
Account: local dutypark_demo
Source: actual app capture, not generated UI
```

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
explicitly requested UI-test run, extract the attachments with the repository
script:

```sh
scripts/extract-app-store-captures.sh \
  --result /tmp/Dutypark-demo.xcresult \
  --locale ko \
  --force
scripts/extract-app-store-captures.sh \
  --result /tmp/Dutypark-demo.xcresult \
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
