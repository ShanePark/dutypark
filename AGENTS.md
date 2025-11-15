# Dutypark – Agent Operations Manual

Use this document whenever you change code in Dutypark. It distills everything an LLM coding agent needs—no marketing fluff, no redundant facts.

---

## 1. Core Context

- **Backend:** Kotlin 2.1, Spring Boot 3.5.x (Data JPA, Web, WebFlux, Security, Validation, Actuator, DevTools, Scheduling, Async, Caching)
- **Frontend:** Thymeleaf layout + Vue.js components, Bootstrap 5, dayjs, SweetAlert2, WaitMe, Pickr, SortableJS, Uppy
- **Persistence:** MySQL 8.0 via Flyway migrations (`db/migration/v1`, `v2`); ULID entities for attachments/schedules/todos
- **Auth:** JWT access cookies + sliding refresh tokens, Kakao OAuth SSO, `@Login` argument resolver
- **AI:** Spring AI + Gemini 2.0 Flash Lite for schedule time parsing (queue manager + worker in `schedule/timeparsing`)
- **Observability:** Micrometer Prometheus registry, Slack lifecycle/error hooks, rolling Logback files
- **Deployment:** Docker Compose stack: app, mysql, nginx (TLS), Prometheus, Grafana (+ standalone MySQL stack in `dutypark_dev_db`)

### Key Modules & Responsibilities

| Module        | Highlights                                                                                                                     |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `attachment/` | Upload sessions, validation/blacklist, filesystem abstraction, thumbnail generation, nightly cleanup, permission evaluator.    |
| `schedule/`   | Schedule CRUD, tagging, search, AI parsing queue/worker, attachment orchestration, visibility enforcement via `FriendService`. |
| `duty/`       | Calendar duties, Excel batch import (`SungsimCakeParser`) for members/teams, duty type management.                             |
| `todo/`       | UUID todos, draggable ordering with SortableJS, reopen/complete logic, modal detail/edit flows.                                |
| `team/`       | Teams, managers, duty types/colors (Pickr UI), work-type presets, shared team schedules.                                       |
| `member/`     | Friends/family, D-Day events, refresh tokens, SSO onboarding, `@Login` annotation.                                             |
| `dashboard/`  | Aggregated “my + friends” snapshot (duties, schedules, requests, pins).                                                        |
| `security/`   | Jwt provider/filter, Kakao OAuth plumbing, admin filter/forwarded header filter, cookie configuration.                         |
| `common/`     | Core configs (async, clock, storage, logging), cached `/api/calendar`, Slack notifier, DataGoKr client, exception advisors.    |

### High-Impact Features

- Duty calendar with visibility-aware data, manager checks, Excel batch import, default off-type fallback.
- Schedule editor with attachments (session-based Uppy uploads, thumbnails via Thumbnailator/TwelveMonkeys, cleanup scheduler).
- AI-assisted time parsing queue that respects Gemini rate limits (30 RPM / 1500 RPD) and populates `contentWithoutTime`.
- Todo overview modal (SortableJS reorder, reopen/complete, SweetAlert confirmations).
- D-Day creation with SweetAlert, privacy flag, localStorage selection for quick display.
- Dashboard showing my duty + today’s schedules plus friends/family insights and request management.
- Team schedule board and templates, plus DataGoKr-powered holiday sync with caching and concurrency locks.
- Slack notifications for startup/shutdown and error detections (request payload + metadata).

---

## 2. Build & Run Reference

```bash
./gradlew bootRun          # dev server (DevTools toggled in application-dev.yml)
./gradlew test             # fail-fast H2 + Mockito suites
./gradlew build            # compiles + tests + bootJar (plain jar disabled)
./gradlew asciidoctor      # runs tests, exports REST Docs to static/docs

docker compose up -d                               # full stack (nginx TLS)
NGINX_CONF_NAME=nginx.local.conf docker compose up -d   # HTTP-only local stack
cd dutypark_dev_db && docker compose up -d               # standalone MySQL on :3307
```

### Build Guidelines

- **Frontend-only changes** (JS/HTML/CSS under `src/main/resources/static/` or `templates/`): no Gradle build is required; verify in-browser (Boot DevTools hot reload covers most cases).
- **Backend changes** (Kotlin/Java, dependencies, configuration): run `./gradlew build` (or at least `./gradlew test`) to compile and catch regressions.
- **API/testing work**: prefer `./gradlew test` for quick feedback; rerun `./gradlew asciidoctor` when controller contract changes impact docs.

### Configuration Essentials

- Copy `.env.sample` → `.env`, then populate DB creds, JWT secret (base64), Slack token, DataGoKr key, Kakao key, Gemini key, domain, `COOKIE_SSL_ENABLED`, `NGINX_CONF_NAME`, `UID/GID`, `TZ`.
- `application.yml`: toggles storage root/size/blacklist, Slack/DataGoKr keys, AI base URL/model/temperature, actuator exposure, Flyway, logging.
- `application-dev.yml`: points to `localhost:3307`, enables DevTools & LiveReload, disables SSL, seeds fake secrets, logs to local path.
- Storage is centralized under `dutypark.storage.root` (permanent) and `<root>/_tmp` (sessions). Update `StoragePathResolver` + cleanup scheduler if adding contexts.
- AI parsing auto-disables when `GEMINI_API_KEY` is blank—preserve this behavior when touching `schedule/timeparsing`.

---

## 3. Infra & Ops Notes

- **Docker:** `docker-compose.yml` wires mysql → app → nginx, plus Prometheus/Grafana; app logs + storage are volume-mounted (`./data/logs`, `./data/storage`). `dutypark_dev_db` provides a lightweight DB-only stack.
- **nginx:** Configs under `data/nginx*.conf` (HTTPS vs HTTP). Includes HTTP→HTTPS redirect, Let’s Encrypt mounts, `/actuator` IP allowlist, static caching, strict security headers.
- **Monitoring:** Prometheus config at `data/prometheus/prometheus.yml` scrapes `app:8080/actuator/prometheus`; Grafana served on `:3000` with persistent volume `./data/grafana`.
- **Logging:** `LogbackConfig` writes daily rolling files to `dutypark.log.path` (default `/dutypark/logs`). Keep log path in sync with Docker volumes when changing.
- **Slack:** `ApplicationStartupShutdownListener` announces lifecycle with `git.properties` info; `ErrorDetectAdvisor` pushes stack traces + request context; optional `@SlackNotification` aspect for domain events.
- **Scheduled jobs:** Attachment session cleanup (02:00 every day) and AI parsing worker. Ensure new async code respects existing executors/logging.

---

## 4. Coding Conventions & Gotchas

### Backend

- Constructor injection only; annotate services with `@Service` + `@Transactional`.
- Use `logger()` extension from `common/config/LogbackConfig.kt`.
- Respect visibility/ownership checks (`FriendService`, `SchedulePermissionService`, `AttachmentPermissionEvaluator`).
- When adding upload contexts or storage tweaks, update every layer: DTO, validation, path resolver, cleanup scheduler, and Docker volume expectations.
- Schedule updates should reset `ParsingTimeStatus` to `WAIT` and push tasks onto the queue when content/time changes.
- For multi-threaded writes (e.g., worker), avoid relying on JPA dirty checking—explicit `save` already in place.

### Frontend

- All templates extend `layout/layout.html`; shared assets live in `layout/include.html`.
- Use Vue mixins/modules under `static/js/duty`. Keep new logic modular (e.g., `todoListMethods`, `searchResultMethods` pattern).
- **Styling rules:** Bootstrap utility classes over inline styles (`class="mt-2 d-flex"` instead of `style="margin-top: 10px"`); inline styles only for dynamic values (colors, computed spacing).
- Attachment UI (`detail-view-modal.js`) lazy-loads Uppy; maintain session/ETA tracking data structures.

### Code Comments Policy

- Prefer self-documenting code; only comment when explaining non-obvious reasoning, workarounds, or subtle edge cases.
- Document “why” not “what”; avoid comments that restate simple logic or variable names.
- If you must work around third-party quirks (e.g., Vue reactivity), note it briefly so future changes don’t regress.

---

## 5. Testing & Docs

- **Structure:** service-layer unit tests (Mockito), controller/integration tests, REST Docs generation, all JUnit 5.
- **Best practices:** cover security (permissions, ownership), edge cases (empty lists, boundaries), performance (N+1, transactions), and error handling (missing resources, storage failures).
- **Commands:** use `./gradlew test --tests "ClassName"` or `./gradlew clean test --tests "*ControllerTest"` for targeted runs; `./gradlew test jacocoTestReport` for coverage.
- **REST Docs:** `./gradlew asciidoctor` depends on tests; output copied to `src/main/resources/static/docs`. Keep docs build passing when editing controllers.

---

## 6. Collaboration Preferences

- Confirm unclear requirements with short, numbered questions (user answers by number).
- Favor TDD-ish workflow: implement backend pieces first, then frontend, especially for cross-cutting features.
- Introduce new configuration via `application.yml` with safe defaults, surface env overrides through `.env.sample`.
- When feasible, capture decisions/specs in `issue-*.md`.

### Task Execution Guidelines

- Work on **one checklist item at a time**; do not parallelize.
- Break each checklist item into 3–5 small todos; finish all todos for the current item before moving on.
- After finishing a checklist item, **stop and present the code for review**—do not continue until the user approves.
- **Never commit automatically**; wait for explicit instructions like “commit this.”
- Only start the next checklist item after user confirms the previous one and requests the commit (if any).
- **User Communication:** All agent responses to user messages must be written in Korean.

---

## 7. Git Commit Policy & Convention

**Absolutely do not commit unless the user explicitly asks.**

- No proactive commits, even if the task feels done. Never suggest committing unless requested.
- When asked to commit:
  - Analyze only the code diff since the last commit; ignore conversation history.
  - Format: `type: summary`, where `type ∈ {feat, fix, chore, refactor}`.
  - Summary must be concise, imperative, English, no trailing period, no mixed languages.
  - Optional body: blank line after summary, wrap at ~72 chars; mention issues only when relevant.
  - Run `git log --oneline -10` first to ensure message aligns with recent style; amend if needed.

---

## 8. Quick Command Reminders

```bash
# Environment bootstrap
cp .env.sample .env && edit placeholders

# Docker helpers
docker compose up -d                       # full stack
docker compose down                       # stop stack
cd dutypark_dev_db && docker compose up -d  # DB-only

# Attachments / storage
ls ./data/storage                         # host-side storage mount
```

---

Keep this file close. If a change needs knowledge beyond this guide, consult `README.md`, the package source, or ask clarifying questions before coding.
