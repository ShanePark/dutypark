# Dutypark – Agent Operations Manual

Use this document whenever you change code in Dutypark. It distills everything an LLM coding agent needs—no marketing fluff, no redundant facts.

---

## 1. Core Context

- **Backend:** Kotlin 2.1, Spring Boot 3.5.x (Data JPA, Web, WebFlux, Security, Validation, Actuator, DevTools, Scheduling, Async, Caching)
- **Frontend:** Vue 3 SPA (Vite + TypeScript + Pinia + Tailwind CSS), fully separated from backend
- **Persistence:** MySQL 8.0 via Flyway migrations (`db/migration/v1`, `v2`); ULID entities for attachments/schedules/todos
- **Auth:** JWT Bearer tokens + sliding refresh tokens (SPA), Kakao OAuth SSO, `@Login` argument resolver
- **AI:** Spring AI + Gemini 2.0 Flash Lite for schedule time parsing (queue manager + worker in `schedule/timeparsing`)
- **Observability:** Micrometer Prometheus registry, Slack lifecycle/error hooks, rolling Logback files
- **Deployment:** Docker Compose stack: app, mysql, nginx (TLS), Prometheus, Grafana (+ standalone MySQL stack in `dutypark_dev_db`)

### Architecture Overview

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

### Key Modules & Responsibilities

| Module        | Highlights                                                                                                                     |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `attachment/` | Upload sessions, validation/blacklist, filesystem abstraction, thumbnail generation, nightly cleanup, permission evaluator.    |
| `schedule/`   | Schedule CRUD, tagging, search, AI parsing queue/worker, attachment orchestration, visibility enforcement via `FriendService`. |
| `duty/`       | Calendar duties, Excel batch import (`SungsimCakeParser`) for members/teams, duty type management.                             |
| `todo/`       | UUID todos, draggable ordering with SortableJS, reopen/complete logic.                                                         |
| `team/`       | Teams, managers, duty types/colors, work-type presets, shared team schedules.                                                  |
| `member/`     | Friends/family, D-Day events, refresh tokens, SSO onboarding, `@Login` annotation.                                             |
| `dashboard/`  | Aggregated "my + friends" snapshot (duties, schedules, requests, pins).                                                        |
| `security/`   | JWT provider/filter, Bearer token support, Kakao OAuth, admin filter, CORS configuration.                                      |
| `common/`     | Core configs (async, clock, storage, logging), cached `/api/calendar`, Slack notifier, DataGoKr client, exception advisors.    |

### High-Impact Features

- Duty calendar with visibility-aware data, manager checks, Excel batch import, default off-type fallback.
- Schedule editor with attachments (session-based Uppy uploads, thumbnails via Thumbnailator/TwelveMonkeys, cleanup scheduler).
- AI-assisted time parsing queue that respects Gemini rate limits (30 RPM / 1500 RPD) and populates `contentWithoutTime`.
- Todo management with SortableJS drag-drop reordering, reopen/complete logic.
- D-Day creation with privacy flag, localStorage selection for quick display.
- Dashboard showing my duty + today's schedules plus friends/family insights and request management.
- Team schedule board and templates, plus DataGoKr-powered holiday sync with caching and concurrency locks.
- Slack notifications for startup/shutdown and error detections (request payload + metadata).

---

## 2. Build & Run Reference

### Backend

```bash
./gradlew bootRun          # dev server (DevTools toggled in application-dev.yml)
./gradlew test             # fail-fast H2 + Mockito suites
./gradlew build            # compiles + tests + bootJar (plain jar disabled)
./gradlew asciidoctor      # runs tests, exports REST Docs to static/docs
```

### Frontend (Vue 3 SPA)

```bash
cd frontend
npm install                # install dependencies
npm run dev                # dev server at http://localhost:5173
npm run build              # production build to dist/
npm run type-check         # TypeScript type checking (vue-tsc)
```

### Docker

```bash
docker compose up -d                               # full stack (nginx TLS)
NGINX_CONF_NAME=nginx.local.conf docker compose up -d   # HTTP-only local stack
cd dutypark_dev_db && docker compose up -d               # standalone MySQL on :3307
```

### Build Guidelines

**Backend changes** (Kotlin/Java, dependencies, configuration):
- Run `./gradlew build` (or at least `./gradlew test`) to compile and catch regressions
- Examples: Controllers, Services, Repositories, Entity classes, configuration files

**Frontend changes** (Vue/TypeScript/CSS under `frontend/`):
- Run `npm run type-check` to verify TypeScript types
- Run `npm run build` for production build verification
- Dev server auto-reloads on file changes

**API/testing work**:
- Prefer `./gradlew test` for quick feedback
- Rerun `./gradlew asciidoctor` when controller contract changes impact docs

### Configuration Essentials

- Copy `.env.sample` → `.env`, then populate DB creds, JWT secret (base64), Slack token, DataGoKr key, Kakao key, Gemini key, domain, `COOKIE_SSL_ENABLED`, `NGINX_CONF_NAME`, `UID/GID`, `TZ`.
- `application.yml`: toggles storage root/size/blacklist, Slack/DataGoKr keys, AI base URL/model/temperature, actuator exposure, Flyway, logging.
- `application-dev.yml`: points to `localhost:3307`, enables DevTools & LiveReload, disables SSL, seeds fake secrets, logs to local path.
- Storage is centralized under `dutypark.storage.root` (permanent) and `<root>/_tmp` (sessions). Update `StoragePathResolver` + cleanup scheduler if adding contexts.
- AI parsing auto-disables when `GEMINI_API_KEY` is blank—preserve this behavior when touching `schedule/timeparsing`.

---

## 3. Frontend Architecture (Vue 3 SPA)

### Directory Structure

```
frontend/
├── src/
│   ├── api/                    # API client modules (Axios)
│   │   ├── client.ts           # Axios instance, interceptors, token management
│   │   ├── auth.ts             # Authentication (Bearer tokens, OAuth)
│   │   ├── admin.ts            # Admin API (separate /admin/api base)
│   │   ├── dashboard.ts        # Dashboard aggregation
│   │   ├── duty.ts             # Duty calendar
│   │   ├── todo.ts             # Todo CRUD + ordering
│   │   ├── schedule.ts         # Schedule CRUD + tags + search
│   │   ├── member.ts           # Member/friends/D-Day
│   │   ├── team.ts             # Team management
│   │   └── attachment.ts       # File upload sessions
│   ├── components/
│   │   ├── common/             # FileUploader, YearMonthPicker, AttachmentGrid, ImageViewer
│   │   ├── duty/               # DayDetailModal, TodoModals, DDayModal, OtherDutiesModal, etc.
│   │   └── layout/             # AppLayout, AppHeader, AppFooter
│   ├── composables/            # useSwal, useKakao
│   ├── stores/auth.ts          # Pinia authentication store
│   ├── views/                  # Page-level components
│   │   ├── auth/               # LoginView, OAuthCallbackView, SsoSignupView, SsoCongratsView
│   │   ├── dashboard/          # DashboardView
│   │   ├── duty/               # DutyView
│   │   ├── member/             # MemberView
│   │   ├── team/               # TeamView, TeamManageView
│   │   ├── admin/              # AdminDashboardView, AdminTeamListView
│   │   └── NotFoundView.vue
│   ├── types/index.ts          # TypeScript type definitions
│   ├── router/index.ts         # Vue Router configuration
│   └── style.css               # Tailwind CSS + design tokens
├── vite.config.ts              # Vite config (proxy: /api → localhost:8080)
└── package.json
```

### Key Technologies

- **Vue 3** with Composition API (`<script setup>`)
- **TypeScript** for type safety
- **Pinia** for state management (auth store)
- **Vue Router** with lazy-loaded routes and navigation guards
- **Axios** with request/response interceptors for JWT handling
- **Tailwind CSS** for styling (custom design tokens in `style.css`)
- **SweetAlert2** via `useSwal` composable
- **SortableJS** for drag-drop reordering
- **Uppy** for file uploads with progress tracking
- **dayjs** for date handling

### Authentication Flow

1. User logs in via `LoginView.vue` → calls `authApi.loginWithToken()`
2. Receives JWT tokens → stored in `localStorage` via `tokenManager`
3. Axios request interceptor adds `Authorization: Bearer {token}` header
4. On 401 response → auto-refresh via response interceptor with request queue
5. Router guards check `authStore.isLoggedIn` before navigation

### API Client Pattern

```typescript
// All API modules follow this pattern
import apiClient from './client'

export const exampleApi = {
  getItems: () => apiClient.get<ItemDto[]>('/items'),
  createItem: (data: CreateItemDto) => apiClient.post<ItemDto>('/items', data),
  updateItem: (id: string, data: UpdateItemDto) => apiClient.put<ItemDto>(`/items/${id}`, data),
  deleteItem: (id: string) => apiClient.delete(`/items/${id}`)
}
```

### Router Structure

| Path | View | Auth | Notes |
|------|------|------|-------|
| `/` | DashboardView | Optional | Guest sees intro |
| `/auth/login` | LoginView | Guest only | |
| `/auth/sso-signup` | SsoSignupView | Optional | |
| `/auth/sso-congrats` | SsoCongratsView | Required | |
| `/auth/oauth-callback` | OAuthCallbackView | Optional | |
| `/duty/:id` | DutyView | Optional | Visibility check |
| `/member` | MemberView | Required | |
| `/team` | TeamView | Required | |
| `/team/manage/:teamId` | TeamManageView | Required | Permission check |
| `/admin` | AdminDashboardView | Admin | |
| `/admin/teams` | AdminTeamListView | Admin | |

---

## 4. Infra & Ops Notes

- **Docker:** `docker-compose.yml` wires mysql → app → nginx, plus Prometheus/Grafana; app logs + storage are volume-mounted (`./data/logs`, `./data/storage`). `dutypark_dev_db` provides a lightweight DB-only stack.
- **nginx:** Configs under `data/nginx*.conf` (HTTPS vs HTTP). Includes HTTP→HTTPS redirect, Let's Encrypt mounts, `/actuator` IP allowlist, static caching, strict security headers.
- **Monitoring:** Prometheus config at `data/prometheus/prometheus.yml` scrapes `app:8080/actuator/prometheus`; Grafana served on `:3000` with persistent volume `./data/grafana`.
- **Logging:** `LogbackConfig` writes daily rolling files to `dutypark.log.path` (default `/dutypark/logs`). Keep log path in sync with Docker volumes when changing.
- **Slack:** `ApplicationStartupShutdownListener` announces lifecycle with `git.properties` info; `ErrorDetectAdvisor` pushes stack traces + request context; optional `@SlackNotification` aspect for domain events.
- **Scheduled jobs:** Attachment session cleanup (02:00 every day), refresh token cleanup (00:00 daily), and AI parsing worker. Ensure new async code respects existing executors/logging.

---

## 5. Coding Conventions & Gotchas

### Backend

- Constructor injection only; annotate services with `@Service` + `@Transactional`.
- Use `logger()` extension from `common/config/LogbackConfig.kt`.
- Respect visibility/ownership checks (`FriendService`, `SchedulePermissionService`, `AttachmentPermissionEvaluator`).
- When adding upload contexts or storage tweaks, update every layer: DTO, validation, path resolver, cleanup scheduler, and Docker volume expectations.
- Schedule updates should reset `ParsingTimeStatus` to `WAIT` and push tasks onto the queue when content/time changes.
- For multi-threaded writes (e.g., worker), avoid relying on JPA dirty checking—explicit `save` already in place.
- JWT supports both cookie-based auth (legacy) and Bearer token auth (SPA); both flows coexist.

### Frontend

- Use Composition API (`<script setup lang="ts">`) for all new components.
- Follow existing patterns in `src/api/` for API client modules.
- Use `useSwal()` composable for all user notifications and confirmations.
- **Styling rules:** Tailwind utility classes over inline styles; custom design tokens defined in `style.css`.
- Keep components focused; extract reusable logic to `composables/`.
- Type all API responses using interfaces in `types/index.ts`.

### Dark Mode & Responsive Design (CRITICAL)

**Every UI change must consider both dark mode and responsive design.**

- **Dark mode:** Use CSS variables (`--dp-*`) from `style.css` instead of hardcoded colors. For hover states, use utility classes like `hover-bg-light` that respect the current theme.
- **Avoid hardcoded colors:** Don't use `bg-gray-50`, `hover:bg-gray-100`, etc. directly. Instead use theme-aware variables or utility classes.
- **Interactive elements:** All clickable elements must have:
  - `cursor-pointer` for visual feedback
  - Hover state that works in both light and dark modes
  - Appropriate touch targets for mobile (min 44px)
- **Responsive breakpoints:** Always test with mobile-first approach. Use Tailwind's responsive prefixes (`sm:`, `md:`, `lg:`) consistently.
- **Common patterns:**
  ```css
  /* Good: Theme-aware hover */
  class="hover-bg-light cursor-pointer"
  :style="{ backgroundColor: 'var(--dp-bg-card)' }"

  /* Bad: Hardcoded colors that break in dark mode */
  class="bg-white hover:bg-gray-50"
  ```

### Code Comments Policy

- Prefer self-documenting code; only comment when explaining non-obvious reasoning, workarounds, or subtle edge cases.
- Document "why" not "what"; avoid comments that restate simple logic or variable names.
- If you must work around third-party quirks (e.g., Vue reactivity), note it briefly so future changes don't regress.
- **All code comments must be written in English only.** No Korean comments in source code—this includes HTML comments (`<!-- -->`), TypeScript comments (`//`, `/* */`), and any other comment syntax.

---

## 6. Testing & Docs

- **Backend Structure:** service-layer unit tests (Mockito), controller/integration tests, REST Docs generation, all JUnit 5.
- **Test Base Classes:** `DutyparkIntegrationTest` (full Spring context + H2), `RestDocsTest` (MockMvc + REST Docs).
- **Best practices:** cover security (permissions, ownership), edge cases (empty lists, boundaries), performance (N+1, transactions), and error handling (missing resources, storage failures).
- **Commands:** use `./gradlew test --tests "ClassName"` or `./gradlew clean test --tests "*ControllerTest"` for targeted runs; `./gradlew test jacocoTestReport` for coverage.
- **REST Docs:** `./gradlew asciidoctor` depends on tests; output copied to `src/main/resources/static/docs`. Keep docs build passing when editing controllers.

### REST Docs Requirements

**When adding new API endpoints, REST Docs tests are mandatory.**

- Every new controller endpoint must have a corresponding test in `*ControllerTest.kt` that extends `RestDocsTest`.
- Document all path parameters, query parameters, request fields, and response fields.
- For empty/optional arrays, use `subsectionWithPath()` instead of `fieldWithPath()` to avoid type inference errors.
- Update `src/docs/asciidoc/index.adoc` to include new endpoint documentation.
- Run `./gradlew asciidoctor` after adding tests to verify documentation generates correctly.
- Reference: See `FriendControllerTest.kt` or `TeamControllerTest.kt` for comprehensive examples.

### Frontend Testing

- TypeScript type checking: `npm run type-check`
- Build verification: `npm run build`

### Playwright MCP Usage

**Use Playwright MCP only when necessary.** Do not use it for routine verification.

- **When to use:**
  - Complex UI interactions that cannot be verified by code inspection alone (drag-and-drop, multi-step workflows)
  - Debugging visual regressions or layout issues reported by user
  - Verifying OAuth/SSO flows that require actual browser state
  - User explicitly requests browser-based testing
- **When NOT to use:**
  - Simple CRUD operations verifiable via API or unit tests
  - Styling changes (verify in browser manually or trust Tailwind classes)
  - Routine feature implementation (trust the code, verify via existing tests)
  - When `./gradlew test` or manual browser refresh suffices

---

## 7. Collaboration Preferences

- Confirm unclear requirements with short, numbered questions (user answers by number).
- Favor TDD-ish workflow: implement backend pieces first, then frontend, especially for cross-cutting features.
- Introduce new configuration via `application.yml` with safe defaults, surface env overrides through `.env.sample`.
- When feasible, capture decisions/specs in `issue-*.md`.

### Task Execution Guidelines

- Work on **one checklist item at a time**; do not parallelize.
- Break each checklist item into 3–5 small todos; finish all todos for the current item before moving on.
- Follow a strict **RED → GREEN → REFACTOR** cadence for every feature or fix; do not jump phases or mix steps.
- After finishing a checklist item, **stop and present the code for review**—do not continue until the user approves.
- **Never commit automatically**; wait for explicit instructions like "commit this."
- Only start the next checklist item after user confirms the previous one and requests the commit (if any).
- **User Communication:** All agent responses to user messages must be written in Korean.

### Parallel Execution & Sub-agent Strategy

**Before starting any task, always evaluate opportunities for safe parallel execution.**

- **Assess parallelizability first:** Identify independent subtasks that don't share mutable state or have dependencies on each other.
- **Use sub-agents proactively:** When multiple independent operations exist (e.g., searching different modules, reading unrelated files, running independent tests), spawn sub-agents in parallel to maximize throughput.
- **Safe parallel patterns:**
  - Reading multiple unrelated files simultaneously
  - Searching across different directories or modules
  - Running independent validation checks
  - Exploring codebase structure from multiple angles
- **Avoid parallel execution when:**
  - Tasks have sequential dependencies (e.g., create file → edit file)
  - Operations modify shared state or the same files
  - Order of execution affects correctness
- **Always prefer parallel sub-agents** for exploration, research, and information gathering tasks—these are inherently safe to parallelize and significantly reduce response time.

---

## 8. Git & GitHub Workflow

### GitHub CLI Usage

**Always use `gh` CLI for GitHub-related operations.**

- Creating issues: `gh issue create --title "..." --body "..."`
- Viewing issues: `gh issue view <number>`
- Creating pull requests: `gh pr create --title "..." --body "..."`
- Viewing pull requests: `gh pr view <number>`
- All GitHub issue titles and descriptions **must be written in English only**.

### Git Commit Policy & Convention

**Absolutely do not commit unless the user explicitly asks.**

- No proactive commits, even if the task feels done. Never suggest committing unless requested.
- When asked to commit:
  - Analyze only the code diff since the last commit; ignore conversation history.
  - Format: `type: summary`, where `type ∈ {feat, fix, chore, refactor}`.
  - Summary must be concise, imperative, **English only**, no trailing period, no mixed languages.
  - Optional body: blank line after summary, wrap at ~72 chars; mention issues only when relevant.
  - Run `git log --oneline -10` first to ensure message aligns with recent style; amend if needed.
- **All commit messages must be written in English only**.

---

## 9. Quick Command Reminders

```bash
# Environment bootstrap
cp .env.sample .env && edit placeholders

# Backend development
./gradlew bootRun                          # Start backend on :8080

# Frontend development
cd frontend && npm run dev                 # Start Vite dev server on :5173

# Docker helpers
docker compose up -d                       # full stack
docker compose down                        # stop stack
cd dutypark_dev_db && docker compose up -d # DB-only on :3307

# Attachments / storage
ls ./data/storage                          # host-side storage mount

# Type checking
cd frontend && npm run type-check          # TypeScript verification
```

---

## 10. API Reference

### Authentication Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/auth/token` | POST | Bearer token login (SPA) |
| `/api/auth/refresh` | POST | Refresh access token |
| `/api/auth/status` | GET | Check login status |
| `/api/auth/password` | PUT | Change password |
| `/api/auth/sso/signup/token` | POST | SSO signup (SPA) |

### Core Domain Endpoints

| Base Path | Domain | Key Operations |
|-----------|--------|----------------|
| `/api/duty` | Duties | GET (monthly), PUT (change), PUT (batch) |
| `/api/schedules` | Schedules | CRUD, search, tag friends, reorder |
| `/api/todos` | Todos | CRUD, reorder, complete/reopen |
| `/api/dashboard` | Dashboard | GET /my, GET /friends |
| `/api/members` | Members | Profile, visibility, managers |
| `/api/friends` | Friends | CRUD, requests, pin/unpin |
| `/api/dday` | D-Day | CRUD |
| `/api/teams` | Teams | Read, schedules, shift view |
| `/api/teams/manage` | Team Admin | Members, duty types, batch upload |
| `/api/attachments` | Files | Upload, download, reorder, sessions |
| `/admin/api` | Admin | Members, teams, refresh tokens |

---

Keep this file close. If a change needs knowledge beyond this guide, consult `README.md`, the package source, or ask clarifying questions before coding.
