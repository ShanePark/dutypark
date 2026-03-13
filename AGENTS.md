# Dutypark – Agent Operations Manual

Use this file for repo-wide defaults only. Keep it lean; read the code and nearby tests for details instead of expanding this document into a full reference manual.

## 1. Current Snapshot

- **Backend:** Kotlin 2.3, Java 25 toolchain, Spring Boot 4.0.1, Spring MVC + WebFlux + Security + Validation + Actuator + Cache + Flyway
- **AI:** Spring AI OpenAI-compatible chat client against Google Generative Language, default model `gemma-3-27b-it`, queue-based schedule time parsing, disabled when `GEMINI_API_KEY` is blank or `EMPTY`
- **Frontend:** Vue 3.5 SPA, Vite 7, TypeScript 5.9, Pinia, Vue Router 4, Tailwind CSS 4, Vitest
- **Persistence / Ops:** MySQL 8.0, Flyway migrations in `src/main/resources/db/migration/v1` and `v2`, Docker Compose stack for app/mysql/nginx/prometheus/grafana
- **Auth:** HttpOnly cookie access/refresh flow for the SPA, Bearer header fallback still supported, Kakao + Naver OAuth, auxiliary accounts, impersonation
- **PWA / Push:** service worker at `frontend/public/sw.js`, VAPID web push, app badge support

## 2. Repo Map

- **Backend modules:** `attachment`, `schedule`, `duty`, `todo`, `team`, `member`, `dashboard`, `notification`, `push`, `holiday`, `policy`, `security`, `common`, `admin`
- **Frontend hotspots:** `frontend/src/api`, `frontend/src/views`, `frontend/src/components`, `frontend/src/stores`, `frontend/src/composables`, `frontend/src/types`, `frontend/src/router`
- **High-signal files when orienting:** `build.gradle.kts`, `src/main/resources/application.yml`, `src/main/resources/application-dev.yml`, `frontend/package.json`, `frontend/src/router/index.ts`, `frontend/src/components/layout/AppHeader.vue`

## 3. Hard Rules

### General

- Do not start backend or frontend dev servers yourself unless the user explicitly asks. Assume the developer handles `./gradlew bootRun` and `cd frontend && npm run dev`.
- Add new configuration in `application.yml` with safe defaults and surface overrides through `.env.sample`.
- Prefer existing patterns over inventing new structure. Read the nearest controller, service, view, and test first.
- When creating GitHub issues or PRs with `gh`, first review a few recently created issues or PRs to match the repository's current conventions, then write the final issue or PR title/body in English.

### Backend

- Use constructor injection. Service-layer code usually stays `@Service` + `@Transactional`.
- Use the `logger()` extension from `common/config/LogbackConfig.kt`.
- Respect visibility and ownership gates: `FriendService`, `SchedulePermissionService`, `AttachmentPermissionEvaluator`, manager checks.
- Cookie auth and Bearer auth both exist. Do not remove one path without checking `JwtAuthFilter`, `CookieService`, backend auth controllers, and `frontend/src/api/client.ts`.
- Scheduled cleanup jobs currently run for refresh tokens at 00:00, attachment sessions at 02:00, notifications at 02:30, and login attempts at 03:00.

### Frontend

- Use `<script setup lang="ts">` for new Vue SFCs.
- Keep authenticated HTTP work inside `frontend/src/api/*.ts`; use shared interfaces from `frontend/src/types/index.ts`.
- Use `useSwal()` for confirmations and user-facing alerts.
- Auth is cookie-based through the shared Axios client. Do not add access-token persistence in localStorage.
- Style with Tailwind utilities and `--dp-*` tokens from `frontend/src/style.css`. Avoid hardcoded hex colors or theme-blind utility colors for surfaces, borders, and text.
- Design frontend UI to work well on both mobile and desktop by default. Check responsive layout, spacing, overflow, and interaction ergonomics across narrow and wide viewports instead of optimizing for only one screen size.
- Inline `:style` is acceptable only for runtime-dependent values or CSS-variable-backed colors already common in the codebase.
- Keep interactive targets at least 44px and preserve visible hover/focus feedback.
- When a task depends on visual quality, layout balance, or interaction polish, verify the result in the browser and iterate. Use Playwright for direct visual checks and feedback loops when static code inspection is not enough.
- When adding a user-facing route, always review both `frontend/src/router/index.ts` and `frontend/src/components/layout/AppHeader.vue`.

### Domain Gotchas

- Attachment contexts currently include `SCHEDULE`, `PROFILE`, `TEAM`, and `TODO`. If you add or change a context, update the enum, validation, storage path resolution, synchronization flow, cleanup expectations, and storage layout together.
- Schedule create/update behavior depends on `ScheduleTimeParsingQueueManager`. Updates currently reset `ParsingTimeStatus` to `WAIT` and requeue parsing; preserve that contract unless the feature spec explicitly changes it.
- The time parsing worker runs off-thread and explicitly saves entities. Do not rely on JPA dirty checking there.
- Push subscription flow depends on a valid refresh token cookie plus service worker registration. Backend and frontend changes often need to move together.
- Notification behavior includes unread polling, exponential backoff, friend-request counts, and app badge updates. Keep those semantics aligned when touching notification UI or APIs.

## 4. Verification Matrix

- **Backend code:** `./gradlew test` or targeted `--tests`
- **Controller / API docs changes:** `./gradlew asciidoctor`
- **Full backend build:** `./gradlew build` (`build` already depends on `asciidoctor`)
- **Frontend changes:** `cd frontend && npm run type-check` and `cd frontend && npm run build`
- **Frontend unit-level logic:** `cd frontend && npm run test` when touching existing Vitest-covered stores or utils, or when adding new unit tests

## 5. Skills To Use

- Dutypark-specific skills live in `./.codex/skills/` inside this repository, not in the global Codex home.
- Use `./.codex/skills/dutypark-restdocs-endpoint/SKILL.md` when changing Spring controller contracts, request or response schemas, or `src/docs/asciidoc`.
- Use `./.codex/skills/dutypark-frontend-page/SKILL.md` when adding or updating Vue pages, routes, hamburger-menu exposure, or theme-sensitive UI.
- Use `./.codex/skills/dutypark-playwright-ui/SKILL.md` for complex browser verification such as drag-drop, modal chains, notification flows, push flows, SSO, visual regressions, or responsive/design validation that needs direct in-browser confirmation.
- Use the existing `$git-commit`, `$pr`, and `$gh-address-comments` skills for Git and GitHub tasks instead of duplicating those workflows here.

## 6. Collaboration Preferences

- Ask short numbered questions only when ambiguity is risky.
- Favor backend-first changes for cross-cutting features.
- Work one checklist item at a time; follow a RED -> GREEN -> REFACTOR rhythm where it fits.
- Stop after each requested checklist item and present the code before moving on.
- If design direction or visual preference needs user input, prefer showing concrete options inside the admin `관리 > 개발` tab (`/admin/dev`) so the user can compare and choose in the product instead of deciding only from chat descriptions.
- Never commit automatically.
- All agent responses to the user must be written in Korean.

## 7. Quick Pointers

- If `frontend/dist/.gitkeep` becomes noisy during local frontend builds, ignore the deletion locally with `git update-index --assume-unchanged frontend/dist/.gitkeep`.
- If this file is not enough, inspect `README.md`, `application*.yml`, the nearest controller or view, and the closest existing test before coding.
