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
| **Kakao OAuth** | One-click login with Korea's most popular messenger |
| **Holiday Sync** | Korean public holidays auto-imported from Data.go.kr with caching |
| **Dark Mode** | Eye-friendly theme that respects your system preference |
| **Mobile-First** | Responsive design optimized for phones and tablets |
| **Web Push** | Native browser push notifications for tags, requests, and updates |
| **PWA Support** | Installable on iOS and Android home screens with offline capability |
| **Account Impersonation** | Managers can switch to managed accounts for viewing/editing |

---

## Tech Stack

- **Backend:** Kotlin 2.3, Spring Boot 4.0 (Data JPA, Security, WebFlux, Scheduling, Caching, AI), Java 21
- **Frontend:** Vue 3.5 SPA (Vite 7 + TypeScript + Pinia + Tailwind CSS 4)
- **Database:** MySQL 8.0 + Flyway migrations (47+ versioned migrations)
- **AI:** Spring AI + Gemini for schedule time parsing with async queue
- **Auth:** JWT Bearer tokens + sliding refresh + Kakao OAuth SSO
- **PWA:** Web Push notifications with VAPID, installable on iOS/Android
- **Observability:** Prometheus, Grafana, Slack webhooks, rolling logs

---

## Quick Start

### Requirements

- JDK 21+, Node.js 20+, Docker (recommended)

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
│   REST API + JWT Auth                   │
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
| `security/` | JWT, OAuth, rate limiting, permissions, admin filtering |

### Frontend Structure

```
frontend/src/
├── api/           # 13 Axios clients (duty, schedule, todo, team, member, notification, push, etc.)
├── components/    # 45+ Vue SFCs (FileUploader, Modals, KanbanBoard, Layout, etc.)
├── composables/   # 7 hooks (useSwal, useKakao, usePushNotification, useEscapeKey, etc.)
├── stores/        # Pinia stores (auth, notification with polling, theme)
├── views/         # 19 page components (Dashboard, Duty, TodoBoard, Member, Team, Admin)
├── utils/         # Helpers (color, date, visibility)
└── types/         # 50+ TypeScript interfaces
```

---

## Configuration

### Essential Environment Variables

| Variable | Purpose |
|:---------|:--------|
| `JWT_SECRET` | Base64-encoded secret for token signing |
| `KAKAO_REST_API_KEY` | Kakao OAuth client credential |
| `GEMINI_API_KEY` | Google AI Studio key for schedule parsing (optional) |
| `SLACK_TOKEN` | Ops notification bot token |
| `DATA_GO_KR_SERVICE_KEY` | Korean public holiday API key |
| `VAPID_PUBLIC_KEY` | Web Push public key (generate via `npx web-push generate-vapid-keys`) |
| `VAPID_PRIVATE_KEY` | Web Push private key |
| `ADMIN_EMAIL` | Admin user email address |

See `.env.sample` for the complete list including DB credentials, domain settings, and Docker configuration.

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

Released under the [MIT License](LICENSE).

---

**Dutypark** — *Because your schedule is more than just work.*
