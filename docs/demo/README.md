# Local demo data and avatar provenance

This directory contains the local-only demo avatars used by the real-app
screenshot workflow. Demo accounts and content must never be created in the
production service.

## Isolated demo account seed

The account base seed is deliberately restricted to:

```text
127.0.0.1:3307/dutypark_demo
```

Provision and migrate that database locally before running the seed. Do not
change the constants in the script to point at `dutypark` or any shared/remote
database. The workflow requires `nc`, `jq`, and either a host `mysql` client or
the local Docker database container. The seed script creates or refreshes the marker team, eight loginable
members, and three team duty types. It does not create profile-photo files,
schedules, Todos, duties, friend relationships, tags, or notifications.

```sh
scripts/seed-local-demo-accounts.sh --dry-run
DUTYPARK_DEMO_CONFIRM=1 scripts/seed-local-demo-accounts.sh
```

The script uses the local MySQL endpoint on port `3307`, checks that the
explicit confirmation variable is present, prints the team/member/duty-type
IDs as JSON, and refuses to continue when a marker email belongs to another
team. The shared demo password is `demo1234!`; it is intentionally local-only
and must not be reused in production or committed to a real account. Re-running
the seed updates only its marker team and accounts. An older marker revision is
removed only when the script finds no references to those members; otherwise
the run stops without deleting application data.

The roster is:

| Role | Name | Login email | Avatar |
|:-----|:-----|:------------|:-------|
| Owner/admin | 윤서아 | `demo.seoa@dutypark.local` | [`seoa-moon-rabbit.png`](avatars/seoa-moon-rabbit.png) |
| Friend | 한지우 | `demo.jiwoo@dutypark.local` | [`jiwoo-coral-bear.png`](avatars/jiwoo-coral-bear.png) |
| Friend | 김도윤 | `demo.doyoon@dutypark.local` | [`doyoon-night-owl.png`](avatars/doyoon-night-owl.png) |
| Friend | 박하린 | `demo.harin@dutypark.local` | [`harin-sunny-puppy.png`](avatars/harin-sunny-puppy.png) |
| Friend | 이민준 | `demo.minjun@dutypark.local` | [`minjun-teal-fox.png`](avatars/minjun-teal-fox.png) |
| Friend | 최유나 | `demo.yuna@dutypark.local` | [`yuna-mint-cat.png`](avatars/yuna-mint-cat.png) |
| Friend | 정태오 | `demo.taeo@dutypark.local` | [`taeo-lavender-otter.png`](avatars/taeo-lavender-otter.png) |
| Friend | 오나리 | `demo.nari@dutypark.local` | [`nari-peach-red-panda.png`](avatars/nari-peach-red-panda.png) |

## Reproducible Korean and English content fixture

English App Store captures use a separate local-only team and dataset so that
the captured user-generated content is English throughout. The team is
`Dutypark English Demo 2026`, with owner `demo.en.emma@dutypark.local` and the
following friends:

| Role | Name | Avatar reused from |
|:-----|:-----|:-------------------|
| Owner/admin | Emma | `seoa-moon-rabbit.png` |
| Friend | Jamie Bear | `jiwoo-coral-bear.png` |
| Friend | Noah Owl | `doyoon-night-owl.png` |
| Friend | Chloe Sunny | `harin-sunny-puppy.png` |
| Friend | Liam Fox | `minjun-teal-fox.png` |
| Friend | Sophia Cat | `yuna-mint-cat.png` |
| Friend | Ethan Otter | `taeo-lavender-otter.png` |
| Friend | Ava Panda | `nari-peach-red-panda.png` |

The English fixture uses the same local-only password, `demo1234!`, and the
same eight generated avatar files. Its schedules, Todo cards, duties, D-Day,
friend relationships, tags, and notifications are generated through the local
application flow with English titles, descriptions, and notification content.
The source for the English capture set is the real local app on `2026-08-29`,
stored under `docs/app-store/raw/en/`; it is not translated or fabricated by
the image-generation step.

The complete content workflow is checked in as
[`scripts/seed-local-demo-content.sh`](../../scripts/seed-local-demo-content.sh).
It first runs the Korean account seed, creates the English marker team and
accounts, uploads these avatars, then creates all API-backed content. It also
inserts only the marker members' capture-date duty rows in a guarded
transaction, because the application has no bulk duty-create endpoint. After
the API identity guard succeeds, it clears only the two marker teams' prior
capture schedules, Todos, D-Days, duties, team schedules, friendships, tags,
and notifications before recreating the deterministic fixture. This prevents
older fixture revisions from accumulating in a refreshed screenshot set. The
English fixture additionally has November 2026 schedules and duties so the
English Calendar, Team, and D-Day captures can show a populated,
holiday-free month.

Run it only after the local migrations and a backend connected to
`dutypark_demo` are running. To preserve a normal development backend on
port `8080`, run the demo backend on `8081` and select that endpoint explicitly:

```sh
scripts/seed-local-demo-content.sh --dry-run
DUTYPARK_DEMO_API_BASE_URL=http://127.0.0.1:8081 \
  scripts/seed-local-demo-content.sh --dry-run
DUTYPARK_DEMO_CONFIRM=1 \
  DUTYPARK_DEMO_API_BASE_URL=http://127.0.0.1:8081 \
  scripts/seed-local-demo-content.sh
```

The script requires `curl`, `jq`, `nc`, and either a host `mysql` client or the
local Docker container. It refuses every target except
`127.0.0.1:3307/dutypark_demo` and loopback API ports `8080` or `8081`, checks all avatar
files before writing, and authenticates both local owner accounts to verify
that the backend's `/api/members/me` response has the exact local member ID,
email, name, and marker team ID/name. If the backend is accidentally pointed
at a shared or production database, the script stops before its first API
mutation. It never deletes or updates data outside the two marker teams.
The reset is allowed only after both local owner identities match the exact
database member and marker-team IDs. Avatars are uploaded on every run so an
isolated backend storage root cannot reuse stale database metadata without the
matching files. Re-running the command is therefore safe and leaves the same
content counts. The final JSON
summary reports the isolated database, both team IDs, account counts, and
content counts. The password and every fixture are local-only; do not run the
command with production credentials or a shared database.

## Populate and capture the scenario

The content script runs the local backend against `dutypark_demo` and uses the
authenticated application API for the rest of the fixture. It uploads each
avatar through `PUT /api/members/profile-photo` as multipart image data while
logged in as that member. It creates the send/accept friend flows and
schedule/Todo content through the API/service flow so reverse friend rows,
tags, and after-commit notifications are generated with valid payloads. Do
not insert notification JSON or profile-photo paths directly into the
database. The seed waits up to 20 seconds for the expected friend-request,
schedule-tag, and Todo-tag notifications before reporting success, so a
capture cannot race the asynchronous after-commit listener.

The capture fixture should include the current `Asia/Seoul` date, at least one
owner/friend schedule and duty for the Home view, a populated calendar month,
Todo cards across statuses, the friend rail and pinned order, tag/friend
notifications, and a future D-Day. Upload photos before creating events so the
notification actor snapshot has the same profile-photo version as the visible
avatar.

The iOS capture test uses the local-only launch guard and the real demo login:

```text
-capture-demo-local-only
-capture-demo-real-account
```

It must run against a localhost API endpoint. The guard intentionally refuses a
remote or production endpoint. When the isolated demo backend runs on `8081`,
pass `API_BASE_URL=http://localhost:8081/api/` to `xcodebuild`. Capture Korean and English independently on an
iPhone 17 Pro Max simulator at `1320x2868`; record the capture date, the locale,
build, device, and endpoint in the capture manifest. Keep raw captures in
`docs/app-store/raw/ko/` and `docs/app-store/raw/en/`. The README gallery uses
the crop-free 660x1434 Korean reductions in `docs/screenshots/readme/`.

Every screenshot-harness invocation resets the session first: it logs out any
currently authenticated account, waits for the guest login screen, and signs
in with the selected Korean or English demo owner. This prevents cookies or
cached account state from leaking between localized capture sets.

## ImageGen provenance

Each avatar was generated in a separate ImageGen call using this shared prompt
prefix and style contract. The bracketed clause was replaced for each file:

```text
Square 1:1 kawaii 3D clay character avatar, [character clause], warm friendly
expression, simple solid pastel background, centered face and shoulders, clean
silhouette, no text, no letters, no logos, high contrast, consistent soft
studio light, Dutypark brand palette coral #FF7B73, teal #20B8B0, sunny yellow
#FFC857, navy #1F2937.
```

| File | Character clause and visual intent |
|:-----|:------------------------------------|
| `seoa-moon-rabbit.png` | Coral-hooded calendar moon rabbit with a tiny teal calendar and yellow crescent accent; friendly owner mascot. |
| `jiwoo-coral-bear.png` | Soft coral bear with a calm, dependable expression and a small teal/yellow planner accent. |
| `doyoon-night-owl.png` | Navy night owl with a gentle sleepy smile and a small moon/calendar cue for late-shift planning. |
| `harin-sunny-puppy.png` | Sunny yellow puppy with bright, welcoming energy and coral/teal accessory accents. |
| `minjun-teal-fox.png` | Teal fox with a curious, organized expression and a coral planner detail. |
| `yuna-mint-cat.png` | Mint-teal cat with a warm smile and a yellow calendar charm. |
| `taeo-lavender-otter.png` | Lavender otter with a relaxed, collaborative expression and restrained Dutypark accent colors. |
| `nari-peach-red-panda.png` | Peach/red-panda character with a cheerful, creative expression and teal/yellow details. |

The generated avatar files are 1254x1254 PNGs and are intended for the
profile-photo upload flow. ImageGen was used only for the character artwork;
the app's UI, text, status bar, account data, and notification contents remain
real captured application output.

The App Store outer artwork follows a separate edit/generation contract:

```text
Preserve the supplied app UI screenshot pixel-for-pixel; do not redraw, correct,
translate, or replace any text, icons, status bar, or data. Add only a restrained
coral-to-cream outer marketing canvas, tiny calendar/moon mascot stickers near
the outer margin, a rounded device-frame edge, and large empty safe areas for
deterministic headline text. No text in the generated layer.
```

The generated decorative files are:

- [`coral-cream-canvas.png`](../app-store/generated/coral-cream-canvas.png) —
  coral-to-cream outer background;
- [`calendar-moon-sticker.png`](../app-store/generated/calendar-moon-sticker.png) —
  small calendar/moon mascot sticker.

The deterministic compositor places headlines and captured UI after generation.
Generated artwork must remain outside the UI content and must never fabricate a
feature state or localized copy.
