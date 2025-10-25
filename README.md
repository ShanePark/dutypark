# Dutypark

[https://dutypark.o-r.kr](https://dutypark.o-r.kr)

<a href="#" target="_blank"><img src="https://img.shields.io/badge/Kotlin-7F52FF?style=flat-square&logo=Kotlin&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/Spring Boot-6DB33F?style=flat-square&logo=Spring-Boot&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/JPA-ED2761?style=flat-square&logo=Spring&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/MySQL-4479A1?style=flat-square&logo=MySQL&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/Thymeleaf-005F0F?style=flat-square&logo=Thymeleaf&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/Vue.js-4FC08D?style=flat-square&logo=Vue.js&logoColor=white"/></a>

> **Add your duties and schedules in a snap — then share with friends or family.**

A lightweight, Kotlin + Spring Boot web app for duty rosters, personal schedules, todos, and D-Day counters. Dutypark combines a Vue-powered calendar UI, AI-assisted schedule parsing, media attachments, and team collaboration so both developers and non-technical users can coordinate shifts, events, and reminders from any device.

---

## 🚀 Features

| Category | Feature | Description |
|:---------------------------|:------------------------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Duty Management** | Duty Calendar | Color-coded duties/off-days with default off-type fallback plus cached calendar grids for quick month navigation. |
|  | Excel Schedule Import | Bulk-upload shifts for a member or entire team via the `SungsimCake` parser; automatically maps names, auto-creates missing members, and overwrites the selected month safely. |
| **Scheduling & Attachments** | Event Scheduling | Rich schedule editor with visibility controls, taggable participants, drag-ordering per day, and attachment-aware CRUD APIs. |
|  | D-Day Countdown | Personal + shared D-Day events with privacy toggle, SweetAlert editor, and local storage selection for quick reference on the calendar. |
|  | LLM Time Parsing Queue | Spring AI + Gemini extracts start/end times from natural-language titles with rate-limited workers and automatic status tracking (WAIT → PARSED/FAILED). |
|  | Schedule Attachments | Session-based uploads powered by Uppy, resumable progress UI, thumbnail generation (Thumbnailator + TwelveMonkeys), and strict permission checks. |
|  | Schedule Search Modal | Full-text search across schedules with pagination and jump-to-day navigation inside the duty calendar. |
| **Todo & Dashboard** | Todo Board & Overview | Vue + SortableJS board for drag reordering, modal editing, reopen/complete actions, overview filters, and inline toasts. |
|  | Dashboard Overview | Daily snapshot for me + friends: duties, schedules, pin ordering, friend/family toggles, and pending request management. |
| **Sharing & Collaboration** | Friend & Family Sharing | Visibility-aware calendar sharing with `Visibility` enums plus family tagging that unlocks additional permissions. |
|  | Schedule Tagging | Tag friends/family to notify them and surface shared schedules in their dashboard/day grid automatically. |
|  | Multi-Account Management | Switch or manage multiple accounts, leveraging refresh tokens/remember-me cookies for frictionless sign-in. |
| **Team & Organizations** | Team Calendars | Team view pulls every member’s roster with aggregated team schedules and default duty colors for empty slots. |
|  | Team Manager Controls | Managers can invite/remove members, configure duty types/colors via Pickr, and manage work types + duty batch templates. |
|  | Team Schedules & Templates | Dedicated team schedule board (`TeamScheduleService`) plus reusable templates for work types, duty defaults, and Excel batch processing. |
| **Integrations & Automation** | Holiday Sync | Data.go.kr (공공데이터포털) integration with caching, DB persistence, and concurrency locks to prevent duplicate imports. |
|  | Slack Ops Hooks | Startup/shutdown updates and exception digests are streamed to Slack via `SlackNotifier` and the `@SlackNotification` aspect. |
| **Monitoring & Ops** | Prometheus + Grafana | Micrometer metrics exposed under `/actuator/prometheus`, scraped by the bundled Prometheus config and visualized via Grafana (default `admin/admin`). |
| **Security** | OAuth Login | Kakao SSO flow with signup/consent screens and `MemberSsoRegister` validation. |
|  | JWT + Refresh Cookies | HttpOnly session cookie plus sliding refresh tokens, admin filtering, and cookie security toggles for HTTPS deployments. |

---

## 🧱 Tech Stack

- **Backend:** Kotlin 2.1.10, Spring Boot 3.5.6 (Data JPA, Web, WebFlux, Validation, Security, Actuator, DevTools), Java 21 toolchain.
- **Data:** MySQL 8.0 + Flyway migrations (`db/migration/v1`, `v2`), JPA auditing, ULID entities, optional P6Spy SQL tracing.
- **AI & Messaging:** Spring AI starter (Gemini 2.0 Flash Lite via OpenAI-compatible endpoint) and Slack webhook integrations.
- **Frontend:** Thymeleaf layouts + Vue.js components, Bootstrap 5, dayjs, SweetAlert2, WaitMe, Pickr, SortableJS, Uppy 5, Pretty Checkbox, custom Nexon fonts, and a PWA manifest.
- **Build & Docs:** Gradle Kotlin DSL with `org.asciidoctor.jvm.convert` and git-properties plugin (surfaced in Slack + `/actuator/info`).
- **Observability & Ops:** Micrometer Prometheus registry, Grafana dashboards, Logback rolling files, Docker Compose orchestration.
- **Testing:** JUnit 5, H2 in-memory DB, Mockito-Kotlin, fail-fast Gradle test runs.

---

## 🗂 Architecture Highlights

### Backend modules
- `duty/` — Duty CRUD plus Excel batch ingestion (`DutyBatchSungsimService`) that validates templates, deduplicates names, and bulk-updates team members.
- `schedule/` — Schedule service with tagging, calendar aggregation, search service, and attachment orchestration; includes the AI time parsing queue.
- `todo/` — UUID-based todo entities with reorderable positions, reopen/complete flows, and overview queries.
- `attachment/` — Upload sessions, validation, image thumbnail generation (async executor), cleanup scheduler, and filesystem abstraction.
- `member/` — Friend/family relationships, D-Day management, visibility enforcement, refresh tokens, and SSO onboarding.
- `team/` — Team CRUD, manager roles, duty type configuration, work-type presets, and shared team schedules.
- `dashboard/` — Aggregated "my + friends" view composed of duty, schedule, and friend request data.
- `holiday/` — DataGoKr client built with `WebClientAdapter` + caching, locking, and DB persistence/reset APIs.
- `security/` — JWT provider, cookies, Kakao OAuth, `@Login` argument resolver, admin filter, and forwarded-header support.
- `common/` — Layout helpers, cached `/api/calendar` grids, Slack notification infrastructure, async/throttle configs, and custom logging configuration.

### Frontend layers
- Thymeleaf layout (`templates/layout`) injects shared head/footer assets and a mobile-first footer dock.
- Vue roots under `templates/duty`, `dashboard.html`, `member/*.html`, and `team/*.html` consume REST APIs for data hydration.
- `static/js/duty/*` modules cover calendar rendering, D-Day modal, todo modals, search modal, attachment detail modal, and other UI fragments.
- Asset pipeline loads Bootstrap, dayjs, Vue, SortableJS, Uppy, Pickr, SweetAlert2, WaitMe, and Kakao/Naver logos via `layout/include.html`.
- Static assets ship with a manifest, icons, and custom fonts for PWA installation.

### Integrations & automation
- Spring Scheduling powers attachment session cleanup (2am) and AI parsing queues; caching is enabled for calendars/holidays.
- Slack notifier sends startup/shutdown/events plus opt-in `@SlackNotification` aspect messages.
- `DataGoKrConfig` uses WebFlux for resilient API calls with custom timeouts.
- Attachment thumbnails run in a dedicated async executor to keep upload requests snappy.

---

## 🧑‍💻 Local Development

### Requirements
- JDK 21+
- Docker & Docker Compose (optional but recommended for full-stack/local DB)
- MySQL client (optional) for direct DB access

### Clone & configure
```bash
git clone https://github.com/ShanePark/dutypark.git
cd dutypark
cp .env.sample .env   # fill in the placeholders before running the stack
```

### Run with Gradle
```bash
./gradlew bootRun          # launches the Spring Boot app (DevTools enabled via application-dev.yml)
./gradlew test             # runs fail-fast unit/integration tests on H2
./gradlew build            # compiles + runs tests
./gradlew asciidoctor      # generates Spring REST Docs into src/main/resources/static/docs
```

### Run with Docker Compose
```bash
# HTTP-only local stack (uses data/nginx.local.conf and skips TLS)
NGINX_CONF_NAME=nginx.local.conf docker compose up -d

# Production-style stack (HTTPS + nginx reverse proxy)
docker compose up -d
```
The Compose file spins up MySQL, the Spring Boot app, nginx (with HTTP→HTTPS redirect + HSTS), Prometheus, and Grafana. App logs and attachment storage are bind-mounted under `./data/`.

### Development database only
Need just MySQL while running the app via Gradle? Use the helper stack:

```bash
cd dutypark_dev_db
docker compose up -d   # exposes MySQL on localhost:3307
```

Point `application-dev.yml` (already configured) or your `.env` to `jdbc:mysql://localhost:3307/dutypark`.

### Production deployment checklist
1. Provision a domain + TLS certificates (Let's Encrypt).  
2. Update `.env` with production secrets (DB, JWT, OAuth, Slack, Gemini, etc.).  
3. Run `docker compose up -d` (defaults to `data/nginx.conf` which assumes HTTPS).  
4. Monitor `/actuator/health` and `/actuator/prometheus` via Prometheus/Grafana.  
5. Rotate secrets and refresh SSL certs periodically.

### Monitoring (optional)
Prometheus and Grafana services are part of the default Compose stack. Grafana listens on `http://localhost:3000` with credentials `admin/admin`, and its data directory persists in `./data/grafana`. Prometheus scrapes `app:8080/actuator/prometheus` as defined in `data/prometheus/prometheus.yml`.

---

## ⚙️ Configuration

### Environment variables (`.env`)
| Key | Purpose |
|:------------------|:----------------------------------------------------------------------------|
| `MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD` | MySQL root/user credentials for the Compose DB container. |
| `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` | Override JDBC connection when deploying outside Compose. |
| `JWT_SECRET` | Base64-encoded secret for signing access tokens (`jwt.secret`). |
| `ADMIN_EMAIL` | Comma-separated admin emails injected into `dutypark.adminEmails`. |
| `SLACK_TOKEN` | Slack bot token for ops notifications. |
| `DATA_GO_KR_SERVICE_KEY` | Public holiday API key (decoded). |
| `KAKAO_REST_API_KEY` | Kakao OAuth client credential. |
| `GEMINI_API_KEY` | Google AI Studio (Gemini) key consumed by Spring AI. |
| `DOMAIN_NAME` | Used by nginx templates + SSL volumes. |
| `COOKIE_SSL_ENABLED` | Toggles Secure flag on cookies (`dutypark.ssl.enabled`). |
| `NGINX_CONF_NAME` | Selects `nginx.conf` (TLS) or `nginx.local.conf` (HTTP). |
| `TZ` | Container timezone (default Asia/Seoul). |
| `UID`, `GID` | File ownership for mounted volumes (logs, Grafana, storage). |

### Application settings
`src/main/resources/application.yml` exposes the most important knobs:

```yaml
spring:
  ai.openai:
    api-key: "${GEMINI_API_KEY:EMPTY}"
    chat:
      base-url: https://generativelanguage.googleapis.com/v1beta/openai/
      options:
        model: gemini-2.0-flash-lite
        temperature: 0.0
dutypark:
  storage:
    root: /dutypark/storage
    max-file-size: 50MB
    thumbnail:
      max-side: 200
    session-expiration-hours: 24
  slack.token: "${SLACK_TOKEN: }"
  data-go-kr.service-key: "${DATA_GO_KR_SERVICE_KEY:DECODED_SERVICE_KEY_HERE}"
jwt:
  secret: "${JWT_SECRET:...}"
management.endpoints.web.exposure.include: health,metrics,prometheus
```

`application-dev.yml` overrides DB credentials (port 3307), enables DevTools, disables SSL, logs to a local directory, and stubs Slack/API keys for safe local testing.

---

## 📁 Directory Guide

| Path | Purpose |
|:--------------------------------------------|:----------------------------------------------------------------------------------------------|
| `src/main/kotlin/com/tistory/shanepark/dutypark/duty` | Duty entities, controllers, services, and Excel batch import logic. |
| `src/main/kotlin/com/tistory/shanepark/dutypark/schedule` | Schedule CRUD, tagging, search, attachments hook, AI parsing queue. |
| `src/main/kotlin/com/tistory/shanepark/dutypark/todo` | Todo controller/service/entity DTOs. |
| `src/main/kotlin/com/tistory/shanepark/dutypark/attachment` | Upload sessions, validation, filesystem helpers, thumbnail services, cleanup scheduler. |
| `src/main/kotlin/com/tistory/shanepark/dutypark/member` | Friend relations, D-Day APIs, refresh tokens, SSO flows, `@Login` annotation. |
| `src/main/kotlin/com/tistory/shanepark/dutypark/team` | Team/domain logic (managers, schedules, work types, duty types). |
| `src/main/kotlin/com/tistory/shanepark/dutypark/security` | JWT auth, filters, Kakao OAuth, admin routing, cookie configuration. |
| `src/main/kotlin/com/tistory/shanepark/dutypark/dashboard` | Dashboard controller/service aggregating duties + schedules. |
| `src/main/resources/templates` | Thymeleaf pages (layout, duty, team, admin, member, error). |
| `src/main/resources/static/js` | Vue modules for duty calendar, dashboard, todo modals, attachment UI, etc. |
| `src/main/resources/db/migration` | Flyway SQL scripts (`v1`, `v2`) that define/upgrade the schema. |
| `src/docs/asciidoc` | Source for Spring REST Docs; build output copied to `static/docs`. |
| `data/` | Docker volumes: MySQL data, logs, nginx templates, Prometheus, Grafana, storage. |
| `dutypark_dev_db/` | Standalone MySQL docker-compose stack for local development. |
| `README.assets/` | Images referenced in documentation (e.g., screenshots). |

---

## 🗂 Attachments & Storage

- Uploads target `AttachmentContextType` (`SCHEDULE`, `PROFILE`, `TEAM`, `TODO`) and start inside a temporary upload session (`AttachmentUploadSessionService`).
- The Vue detail modal initializes Uppy dynamically, creates sessions on demand, enforces size limits (`dutypark.storage.max-file-size`), and tracks realtime progress with ETA + speed estimates.
- `AttachmentService` persists metadata, enforces ownership through `AttachmentPermissionEvaluator`, and triggers thumbnails via `AttachmentUploadedEvent` + `ThumbnailService`.
- Thumbnails are generated asynchronously on the `thumbnailExecutor` (`AsyncConfig`) using Thumbnailator + TwelveMonkeys codecs (JPEG/WebP support).
- `AttachmentCleanupScheduler` runs nightly at 02:00, deletes expired sessions/files, and keeps orphaned uploads out of disk.
- All filesystem paths are resolved through `StoragePathResolver` so you can relocate storage by changing `dutypark.storage.root`.

---

## 🧠 AI-Assisted Scheduling

- `ScheduleTimeParsingQueueManager` monitors schedules with `ParsingTimeStatus.WAIT`, enqueues them, and enforces Gemini limits (30 RPM, 1500 RPD).
- Each task delays 10 seconds to ensure the originating DB transaction is committed, then `ScheduleTimeParsingWorker` skips entries that already have explicit times or lack time-related text.
- `ScheduleTimeParsingService` crafts a JSON-only prompt, strips code fences, and deserializes responses into `ScheduleTimeParsingResponse`.
- Worker outcomes update `ParsingTimeStatus` (`PARSED`, `FAILED`, `NO_TIME_INFO`, `ALREADY_HAVE_TIME_INFO`) and persist start/end times + `contentWithoutTime`.
- Set `GEMINI_API_KEY` (or override `spring.ai.openai.*`) to enable the queue; leaving it blank automatically disables AI parsing without breaking schedule creation.

---

## 🔒 Security & Access Control

- `JwtAuthFilter` reads the HttpOnly session cookie, refreshes expired tokens via sliding refresh tokens (`RefreshTokenService`), and injects `LoginMember` attributes for controllers annotated with `@Login`.
- `AuthService` issues remember-me cookies, revokes refresh tokens on password changes, and honors `dutypark.ssl.enabled` when toggling cookie security.
- Kakao OAuth (`security/oauth/kakao`) handles token exchange + user info, while `/member/sso` pages complete onboarding with terms consent.
- `DutyparkProperties.adminEmails` governs elevated access, and `AdminAuthFilter` restricts `/admin/**` + `/docs/**`.
- Attachment APIs enforce session ownership + context-level permissions; schedule/todo/team controllers delegate to `FriendService` and `SchedulePermissionService` for visibility checks.
- Visibility enums (`PUBLIC`, `FRIENDS`, `FAMILY`, `PRIVATE`) and friend/family relationships determine who can read schedules/duties.
- `ForwardedHeaderFilter` plus nginx headers make deployments reverse-proxy friendly.

---

## 📊 Monitoring & Ops

- Spring Actuator exposes `/actuator/health`, `/actuator/info`, and `/actuator/prometheus` (enabled via `management.endpoints.web.exposure.include`).
- Prometheus config (`data/prometheus/prometheus.yml`) scrapes both itself and the app; Grafana dashboards persist under `data/grafana`.
- Slack alerts: `ApplicationStartupShutdownListener` posts lifecycle notifications (with branch + commit from `git.properties`), while `ErrorDetectAdvisor` sends exception payloads with request metadata.
- Logback writes rolling daily logs to `dutypark.log.path` (default `/dutypark/logs`, mounted via Docker for persistence).
- Micrometer + Prometheus registry capture JVM/app metrics; P6Spy can be toggled via `decorator.datasource.p6spy.enable-logging`.
- `spy.log` (P6Spy output) and `data/logs` help troubleshoot SQL and app behavior.

---

## 🎨 Frontend Experience

- Single layout (`layout/layout.html`) provides shared head assets, icons, manifest, and a fixed footer nav optimized for mobile.
- The duty calendar Vue app (`static/js/duty/duty.js`) hydrates calendar grids, schedules, holidays, todos, and attachments with per-module mixins (`day-grid`, `dday-list`, `todo-*`, `search-result-modal`).
- D-Day management leverages SweetAlert popups, localStorage for quick selection, and supports private events.
- Todo modals and overview leverage SortableJS handles, reposition APIs (`/api/todos/position`), and inline success/error toasts.
- Schedule detail modal integrates Uppy for uploads, real-time progress bars, thumbnail previews, and reordering.
- Team management pages use Pickr for color selection, Pretty Checkbox for toggles, and custom alert flows.
- Custom Nexon font + Bootstrap utilities keep the UI consistent, while PWA manifest & icons allow “Install” prompts on mobile.

---

## 🐳 Docker & Deployment

- `docker-compose.yml` defines five services: `mysql`, `app`, `nginx`, `prometheus`, and `grafana`. App logs + attachment storage are bind-mounted to `./data/logs` and `./data/storage`.
- nginx templates live in `data/nginx.conf` (HTTPS) and `data/nginx.local.conf` (HTTP). Choose them via `NGINX_CONF_NAME`.
- TLS certificates are expected under `/etc/letsencrypt/...` on the host, mounted read-only into the nginx container.
- `/actuator/**` routes are IP-restricted inside the nginx config (allow loopback + Docker networks).
- `dutypark_dev_db/docker-compose.yml` is a trimmed stack for running only MySQL on port 3307.
- `UID/GID` environment variables ensure mounted volumes remain writable on Linux hosts.
- Prometheus + Grafana data directories persist under `./data/prometheus` and `./data/grafana` respectively.

---

## 📄 API Docs & Testing

- `./gradlew test` runs with `failFast = true`, using H2 + Mockito-Kotlin so suites complete quickly.
- `./gradlew asciidoctor` depends on tests, then copies generated REST Docs into `src/main/resources/static/docs` (served under `/docs`, protected by `AdminAuthFilter`).
- Build pipeline disables the plain `jar` task (Spring Boot fat jar only) and wires `build` → `asciidoctor`.
- Use `./gradlew test --tests "SomeTestClass"` to target specific suites; `./gradlew clean build` for release builds.

---

## 🖼 Sample Usage

![eagles](./README.assets/eagles.png)

Enjoy planning with **dutypark**.

---

## 📄 License

Released under the [MIT License](LICENSE).
