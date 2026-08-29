# Dutypark

[한국어](README.ko.md) | [English](README.md)

[https://dutypark.o-r.kr](https://dutypark.o-r.kr)

<a href="#" target="_blank"><img src="https://img.shields.io/badge/Kotlin-7F52FF?style=flat-square&logo=Kotlin&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/Spring Boot-6DB33F?style=flat-square&logo=Spring-Boot&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/JPA-ED2761?style=flat-square&logo=Spring&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/MySQL-4479A1?style=flat-square&logo=MySQL&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/Vue.js-4FC08D?style=flat-square&logo=Vue.js&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/TypeScript-3178C6?style=flat-square&logo=TypeScript&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/PWA-5A0FC8?style=flat-square&logo=PWA&logoColor=white"/></a>

> **A social calendar for you and the people you care about.**

---

## Why Dutypark?

Your schedule isn't just about work. It's about the people around you — your partner who wants to plan a date, your family coordinating around everyone's calendars, your friends sharing their game-day schedules.

**Dutypark connects your daily life with the people who matter most.** Share schedules, coordinate plans, and stay in sync — all in one place.

### Who Uses Dutypark?

| Who | What They Get |
|:----|:--------------|
| **Families** | Share schedules with spouse and kids, never miss daycare pickups or family events |
| **Office Workers** | Track workdays and time-off, share with family so they know when you're free |
| **Sports Fans** | Follow your team's schedule — home/away games, times, venues, opponents |
| **Shift Workers** | Import rosters from Excel, share with family, coordinate with coworkers |
| **Parents** | Manage daycare schedules, school events, weekend activities in one place |

---

## Core Experience

### Share with Intention

Not everyone needs to see everything. Dutypark gives you **four layers of privacy**:

- **Public** — Visible to anyone
- **Friends** — Only approved connections can see
- **Family** — Reserved for your closest circle
- **Private** — Just for you

Tag friends in your schedules. They'll see it on their dashboard instantly. No more "Did you get my text?"

### Your Calendar, Your Way

- **Duty Calendar** — Color-coded shifts with smart defaults for empty days
- **Schedule Events** — Add appointments, meetups, reminders with optional time AI parsing
- **Todo Board** — Drag-and-drop tasks that stay organized
- **D-Day Countdown** — Never forget anniversaries, deadlines, or milestones

### Stay Connected

- **Dashboard** — See your day plus your friends' and family's schedules in one view
- **Notifications** — Get alerted when someone tags you or sends a friend request
- **Team View** — Aggregated roster for your whole team with manager controls

## Native iOS Offline Mode

The native iPhone app has an account-scoped offline mode. This is separate from
the web PWA: iOS can reopen a recently verified account and render its local
calendar and Todo data, while the web service worker currently handles push,
notification-click routing, badges, and locale data only. The web app does not
cache the app shell or arbitrary API responses for offline use; see
[`frontend/README.md`](frontend/README.md#pwa-and-push).

### What iOS keeps locally

Offline data is stored under the app's Application Support directory at
`Dutypark/Offline/accounts/<memberID>/`. Storage is isolated per account and
contains:

- a last server-verified profile snapshot, friend metadata, and D-Days;
- monthly calendar snapshots containing the calendar grid, schedules, duties,
  Korean holidays, and compared-member duty data; and
- the Todo board and locally queued creates.

The calendar cache keeps a rolling thirteen-month window (the current month,
six previous months, and six following months). Cached member snapshots omit
OAuth provider identifiers and access/refresh tokens. A regular, non-managed
session can fall back to its saved identity for up to 30 days; this is a local
snapshot, not proof that the server session is still active.

### What works without a connection

Offline reads are available for cached Calendar and Todo screens. The only
durable offline writes are new, plain schedule and Todo creates:

- a schedule may contain its title/content, description, visibility, and start
  and end times;
- a Todo may contain its title, content, status, and due date; and
- each queued create receives a local UUID and remains visible as a provisional
  item until synchronization completes.

Tags, attachments, AI time parsing, edits, deletes, duty changes, D-Day
changes, friend/team actions, notifications, and other online-only mutations
require a connection. The Home, Social, Team, and Notifications root screens
show an online-required state while offline.

When connectivity returns, the iOS coordinator drains entries in creation
order. The server suppresses duplicate creates using the owning member and
content fields: schedules compare content, description, start time, and end
time; Todos compare effective status, title, and content. Schedule visibility
and Todo due date are intentionally not part of this duplicate identity.
Transient transport/decoding failures and HTTP 408, 425, 429, and 5xx responses
use exponential retry backoff from five seconds up to five minutes. Validation
and permission 4xx responses become a permanent failure that requires an
explicit retry; authentication failures are handled at the session boundary.

Logging out or switching accounts purges that account's cache and outbox.
In-flight work is guarded by the authentication generation and cannot be
applied to the next account. Cached data can be stale, and the server remains
the source of truth after synchronization; iOS does not promise conflict-free
offline editing for updates or deletes.

## Demo Data and Screenshot Workflow

The repository keeps curated, real-app screenshots separate from App Store
submission artwork. Select a preview to open the full-resolution capture.

| Home | Calendar | Todo | Team | Social |
|:---:|:---:|:---:|:---:|:---:|
| [![Home dashboard](docs/screenshots/readme/home.png)](docs/screenshots/readme/home.png) | [![Calendar](docs/screenshots/readme/calendar.png)](docs/screenshots/readme/calendar.png) | [![Todo board](docs/screenshots/readme/todo.png)](docs/screenshots/readme/todo.png) | [![Team calendar](docs/screenshots/readme/team.png)](docs/screenshots/readme/team.png) | [![Friends and social](docs/screenshots/readme/social.png)](docs/screenshots/readme/social.png) |

To refresh the demo set:

1. Use the local Docker MySQL database and local backend/frontend only. Never
   seed demo credentials or personal data through the production service.
2. Create one marker-owned demo account, a team, and several friend accounts;
   populate the current Asia/Seoul date with duties and shared schedules, a
   full calendar month, Todo cards across statuses, friend relationships,
   tags/notifications, and a future D-Day. Keep the marker and account list
   documented with the local-only seed workflow so it can be rebuilt safely.
3. Generate coherent avatar artwork with the repository's image-generation
   workflow, upload each image through the authenticated profile-photo flow,
   and create tag/friend events after the photo versions are current. This
   keeps notification actor snapshots consistent with the visible avatars.
4. Capture the unmodified app UI for the README gallery. Keep raw captures
   separate from any marketing composition and record the locale, app build,
   device, and capture date alongside the files.

Korean and English App Store captures use separate local demo datasets; each
capture run logs out first and signs in to the owner account for its locale.

For App Store assets, maintain separate Korean and English raw sets under
`docs/app-store/raw/{ko,en}/`, with generated artwork in
`docs/app-store/generated/` and deterministic deliverables in
`docs/app-store/final/{ko,en}/`. See the
[`docs/app-store/README.md`](docs/app-store/README.md) workflow. Use real app captures as the source of truth;
generated artwork may provide only a restrained outer canvas, mascot, or
decorative sticker and must not redraw UI text, icons, status bars, or data.
The current iPhone submission reference is the 6.9-inch portrait canvas
`1320x2868`; consult Apple's [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
and [upload guidance](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/)
when preparing or replacing a submission set.

---

## Features at a Glance

### Scheduling & Sharing

| Feature | Description |
|:--------|:------------|
| **Smart Visibility** | 4-level privacy (Public / Friends / Family / Private) with granular control per event |
| **Friend Tagging** | Tag people in schedules — they'll see it on their dashboard and get notified |
| **Family Mode** | Special visibility tier for blood relatives and closest connections |
| **Excel Import** | Bulk-upload shift rosters via the `SungsimCake` parser for healthcare and retail templates |
| **AI Time Parsing** | Natural language like "Meeting 3-5pm" auto-extracts via async Gemini queue (rate-limited) |
| **Position Reordering** | Drag-to-reorder schedules within a day with persistent positioning |

### Personal Productivity

| Feature | Description |
|:--------|:------------|
| **D-Day Countdown** | Track anniversaries, deadlines, and milestones with privacy options |
| **Kanban Todo Board** | Multi-status columns (BACKLOG/TODO/DOING/DONE/CLOSED) with drag-and-drop |
| **Schedule Search** | Full-text search with jump-to-day navigation and pagination |
| **Profile Photo** | Upload and crop profile photos with automatic thumbnail generation |
| **Attachments** | Upload files to schedules with resumable progress and auto-thumbnails |

### Team Collaboration

| Feature | Description |
|:--------|:------------|
| **Team Calendar** | Aggregated view of all members' duties with color-coded types |
| **Manager Controls** | Invite/remove members, configure duty types and colors |
| **Shift Templates** | Configurable batch templates (SungsimCake format) for Excel imports |
| **Team Schedules** | Shared announcements and events visible to all team members |
| **Shift View** | Day-by-day breakdown showing who's on which shift |

### Platform & Integration

| Feature | Description |
|:--------|:------------|
| **Kakao + Naver OAuth** | One-click social login and SSO onboarding for Korean users |
| **Holiday Sync** | Korean public holidays auto-imported from Data.go.kr with caching |
| **Dark Mode** | User-selectable light/dark theme persisted locally |
| **Localized UI** | Korean and English with browser-locale suggestions |
| **Mobile-First** | Responsive design optimized for phones and tablets |
| **Web Push** | Native browser push notifications for tags, requests, and updates |
| **PWA Support** | Installable on iOS and Android home screens with push, badge, and notification-click support |
| **Account Impersonation** | Managers can switch to managed accounts for viewing/editing |

---

## Tech Stack

- **Backend:** Kotlin, Spring Boot 4 (Data JPA, Security, WebFlux, Scheduling, Caching, AI), Java 25 toolchain
- **Frontend:** Vue 3 SPA (Vite + TypeScript + Pinia + Vue Router + Vue I18n + Tailwind CSS 4)
- **Database:** MySQL 8.0 + versioned Flyway migrations
- **AI:** Spring AI OpenAI-compatible client against Gemini for async schedule time parsing
- **Auth:** HttpOnly cookie access/refresh flow + Bearer fallback + Kakao/Naver OAuth SSO
- **PWA:** Web Push notifications with VAPID, refresh-token-bound subscriptions, installable on iOS/Android
- **Observability:** Prometheus, Grafana, Slack webhooks, rolling logs

---

## Quick Start

### Requirements

- JDK 25+, Node.js 20+, Docker (recommended)

### Development Setup

```bash
# Clone and configure
git clone https://github.com/ShanePark/dutypark.git
cd dutypark
cp .env.sample .env  # fill in the placeholders

# Start database
cd dutypark_dev_db && docker compose up -d && cd ..

# Start backend (terminal 1)
./gradlew bootRun

# Start frontend (terminal 2)
cd frontend && npm install && npm run dev
```

Open http://localhost:5173 — the Vite dev server proxies API requests to the backend automatically.

### Production Deployment

```bash
# Build artifacts
./gradlew build
cd frontend && npm run build && cd ..

# Deploy with Docker Compose
docker compose up -d
```

Full production setup (TLS, Prometheus, Grafana) is included in the Compose stack.

---

## Architecture

```
┌─────────────────────────────────────────┐
│      Vue 3 SPA (frontend/)              │
│  Vite dev: http://localhost:5173        │
└────────────┬────────────────────────────┘
             │ /api/* proxy
             ▼
┌─────────────────────────────────────────┐
│   Spring Boot Backend (:8080)           │
│   REST API + Cookie/JWT Auth            │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│   MySQL 8.0 (:3306/3307)                │
└─────────────────────────────────────────┘
```

### Backend Modules

| Module | Responsibility |
|:-------|:---------------|
| `duty/` | Duty CRUD, Excel batch import (`SungsimCakeParser`), calendar aggregation |
| `schedule/` | Events, tagging, search, AI parsing queue/worker, attachments |
| `todo/` | Kanban board with statuses (BACKLOG/TODO/DOING/DONE/CLOSED) |
| `member/` | Friends, family, D-Day, profiles, SSO onboarding, auxiliary accounts |
| `team/` | Teams, managers, duty types, shared schedules, batch templates |
| `dashboard/` | Aggregated "my + friends" daily view with batch loading |
| `notification/` | In-app alerts with event-driven async handling and pagination |
| `push/` | Web Push notifications with VAPID, iOS PWA support |
| `attachment/` | Session-based uploads, thumbnails, nightly cleanup scheduler |
| `holiday/` | Korean public holidays from Data.go.kr with concurrency-safe caching |
| `policy/` | Terms/privacy policy versions and member consent tracking |
| `security/` | JWT, OAuth, rate limiting, permissions, admin filtering |
| `admin/` | Admin member/team inspection, session controls, and impersonation support |
| `common/` | Shared configuration, error responses, paging, logging, and test helpers |

### Frontend Structure

```
frontend/src/
├── api/           # Axios clients (duty, schedule, todo, team, member, notification, push, etc.)
├── components/    # Vue SFCs (FileUploader, Modals, KanbanBoard, Layout, etc.)
├── composables/   # Hooks (useSwal, useKakao, useNaver, usePushNotification, useEscapeKey, etc.)
├── stores/        # Pinia stores (auth, notification with polling, theme, locale)
├── views/         # Page components (Dashboard, Duty, TodoBoard, Member, Team, Admin)
├── i18n/          # Locale bundles for ko/en
├── releaseNotes/  # In-app changelog metadata and localized copy
├── utils/         # Helpers (color, date, visibility)
└── types/         # Shared TypeScript interfaces
```

---

## Configuration

### Essential Environment Variables

| Variable | Purpose |
|:---------|:--------|
| `JWT_SECRET` | Base64-encoded secret for token signing |
| `KAKAO_REST_API_KEY` | Kakao OAuth client credential |
| `NAVER_CLIENT_ID` / `NAVER_CLIENT_SECRET` | Naver OAuth client credentials |
| `VITE_KAKAO_APP_KEY` | Kakao JavaScript SDK app key for the SPA |
| `VITE_NAVER_CLIENT_ID` | Naver OAuth client ID exposed to the SPA |
| `VITE_API_BASE_URL` | Optional absolute backend base URL for OAuth redirects |
| `GEMINI_API_KEY` | Google AI Studio key for schedule parsing (optional) |
| `SLACK_TOKEN` | Ops notification bot token |
| `DATA_GO_KR_SERVICE_KEY` | Korean public holiday API key |
| `VAPID_PUBLIC_KEY` | Web Push public key (generate via `npx web-push generate-vapid-keys`) |
| `VAPID_PRIVATE_KEY` | Web Push private key |
| `ADMIN_EMAIL` | Admin user email address |

See `.env.sample` for the complete list including DB credentials, domain settings, and Docker configuration.
Vite reads `VITE_*` values from `frontend/.env.development`, `frontend/.env.production`, or process environment when building the SPA.

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

For PRs targeting `main`, add exactly one in-app release note entry after the PR number is known and run `cd frontend && npm run release-notes:check`. See `frontend/src/releaseNotes/README.md` for the release-note workflow.

---

## License

Released under the [MIT License](LICENSE).

---

**Dutypark** — *Because your schedule is more than just work.*
