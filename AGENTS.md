# Dutypark – Agent Operations Manual

Use this file for repo-wide defaults only. Keep it lean; read the code and nearby tests for details instead of expanding this document into a full reference manual.

## 1. Current Snapshot

- **Backend:** Kotlin, Java 25 toolchain, Spring Boot 4, Spring MVC + WebFlux + Security + Validation + Actuator + Cache + Flyway
- **AI:** Spring AI OpenAI-compatible chat client against Google Generative Language, default model `gemma-4-31b-it`, queue-based schedule time parsing, disabled when `GEMINI_API_KEY` is blank or `EMPTY`
- **Frontend:** Vue 3 SPA, Vite, TypeScript, Pinia, Vue Router, Vue I18n (`ko`, `en`, `ja`, `zh`, `es`), Tailwind CSS 4, Vitest
- **Persistence / Ops:** MySQL 8.0, Flyway migrations in `src/main/resources/db/migration/v1` and `v2`, Docker Compose stack for app/mysql/nginx/prometheus/grafana, in-app release notes powering PR checks and GitHub Releases
- **Auth:** HttpOnly cookie access/refresh flow for the SPA, Bearer header fallback still supported, Kakao + Naver OAuth, auxiliary accounts, impersonation
- **PWA / Push:** service worker at `frontend/public/sw.js` backed by `frontend/src/push/sw-runtime.ts`, VAPID web push, localized notification text, notification-click routing, and app badge support

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
- Backend API errors currently return machine-readable `code` values through `RestExceptionControllerAdvice`; keep user-facing translations in the frontend i18n bundles unless a feature intentionally introduces backend `MessageSource` support.

### Frontend

- Use `<script setup lang="ts">` for new Vue SFCs.
- Keep authenticated HTTP work inside `frontend/src/api/*.ts`; use shared interfaces from `frontend/src/types/index.ts`.
- Use `useSwal()` for confirmations and user-facing alerts.
- Auth is cookie-based through the shared Axios client. Do not add access-token persistence in localStorage.
- Put user-facing UI copy in `frontend/src/i18n/messages/*.ts`; do not leave hardcoded Korean or English strings in components, composables, or view files unless the string is truly non-user-facing.
- Supported frontend locales currently are `ko`, `en`, `ja`, `zh`, and `es`; keep UI copy, release notes, static notification templates, and service-worker notification text in sync.
- For every human-authored PR targeting `main`, add exactly one release note entry before PR review, even for docs, infra, or maintenance follow-ups. Dependabot-only dependency update PRs are intentionally exempt from in-app release notes and GitHub Release creation. Because the exact PR number is unavailable before GitHub creates the PR, do not guess the next number. Create the PR first so the PR number is known, then immediately add a follow-up commit that updates `frontend/src/releaseNotes/meta.ts` and every `frontend/src/releaseNotes/messages/*.ts` locale file with `id: "pr-<number>"` (currently `en`, `ko`, `ja`, `zh`, `es`). Use the PR date in Asia/Seoul as `YYYY.MM.DD`, then `.02`, `.03`, and so on for additional PRs on the same date. Run `cd frontend && npm run release-notes:check`; the `release-note` job in `.github/workflows/gradle.yml` also runs a PR-number-specific release note gate before merge. GitHub Releases are created on merge from the matching English in-app release note, so do not rely on the PR body as the release note source.
- When using `$pr` for a `main` PR, create it as a draft first with `gh pr create --draft` so the initial CI run does not fail before the release-note commit exists. The required Dutypark sequence is: create the draft PR, capture the PR number, add and commit the `pr-<number>` release note, push that follow-up commit, run `cd frontend && npm run release-notes:check`, run the requested build verification, mark the PR ready with `gh pr ready`, then report the latest CI run for the current head SHA. The `release-note` CI job intentionally skips draft PRs and runs when the PR is marked ready for review.
- Keep auto-detected locale separate from explicit user choice. Browser locale may drive first render or language suggestions, but it should not be treated as a confirmed preference until the user accepts or picks a language.
- In locale pickers and language settings, show language names in their native forms (`한국어`, `English`, `日本語`, `简体中文`, `Español`) rather than translating the language names to the current UI language.
- Style with Tailwind utilities and `--dp-*` tokens from `frontend/src/style.css`. Avoid hardcoded hex colors or theme-blind utility colors for surfaces, borders, and text.
- Design frontend UI to work well on both mobile and desktop by default. Check responsive layout, spacing, overflow, and interaction ergonomics across narrow and wide viewports instead of optimizing for only one screen size. For mobile verification, check both iPhone 16 Pro (402 x 874 CSS px) and iPhone 13 mini (375 x 812 CSS px) portrait viewport sizes.
- Verify user-facing frontend UI in both light and dark modes when checking visual quality, layout, or interaction changes.
- For tight mobile UI slots such as footer tabs, calendar cells, pills, and compact buttons, add dedicated short translation keys instead of reusing longer desktop copy.
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
- **Release notes:** `cd frontend && npm run release-notes:check` when touching `frontend/src/releaseNotes` or preparing a `main` PR

## 5. Skills To Use

- Dutypark-specific skills live in `./.codex/skills/` inside this repository, not in the global Codex home.
- Use `./.codex/skills/dutypark-restdocs-endpoint/SKILL.md` when changing Spring controller contracts, request or response schemas, or `src/docs/asciidoc`.
- Use `./.codex/skills/dutypark-frontend-page/SKILL.md` when adding or updating Vue pages, routes, hamburger-menu exposure, or theme-sensitive UI.
- Use `./.codex/skills/dutypark-playwright-ui/SKILL.md` for complex browser verification such as drag-drop, modal chains, notification flows, push flows, SSO, visual regressions, or responsive/design validation that needs direct in-browser confirmation.
- Use the existing `$git-commit`, `$pr`, and `$gh-address-comments` skills for Git and GitHub tasks instead of duplicating those workflows here.

## 6. Sub-Agent Use

- Consider sub-agent use on every non-trivial task.
- Use sub-agents proactively when independent research, search, verification, or disjoint implementation work can run in parallel within the current checklist item and clearly help.
- When spawning sub-agents, use the same model as the main agent. Do not override the sub-agent model unless the user explicitly asks for a different one.
- Do not use sub-agents for sequential steps, overlapping file edits, or tightly coupled refactors.
- The main agent remains responsible for planning, integration, final verification, and user communication.

## 7. Collaboration Preferences

- Ask short numbered questions only when ambiguity is risky.
- Favor backend-first changes for cross-cutting features.
- Work one checklist item at a time; follow a RED -> GREEN -> REFACTOR rhythm where it fits.
- Stop after each requested checklist item and present the code before moving on.
- If design direction or visual preference needs user input, prefer showing concrete options inside the admin `관리 > 개발` tab (`/admin/dev`) so the user can compare and choose in the product instead of deciding only from chat descriptions.
- Never commit automatically.
- All agent responses to the user must be written in Korean.

## 8. Quick Pointers

- If `frontend/dist/.gitkeep` becomes noisy during local frontend builds, ignore the deletion locally with `git update-index --assume-unchanged frontend/dist/.gitkeep`.
- If this file is not enough, inspect `README.md`, `application*.yml`, the nearest controller or view, and the closest existing test before coding.
