# Dutypark – Agent Operations Manual

Repo-wide defaults only. Read the code and nearby tests for details instead of expanding this document.

## 1. Stack

- **Backend:** Kotlin, Java 25, Spring Boot 4 (MVC + WebFlux + Security + Validation + Actuator + Cache + Flyway), MySQL 8.0
- **AI:** Spring AI OpenAI-compatible client for Google Generative Language, default model `gemma-4-31b-it`; queue-based schedule time parsing; disabled when `GEMINI_API_KEY` is blank or `EMPTY`
- **Frontend:** Vue 3 SPA — Vite, TypeScript, Pinia, Vue Router, Vue I18n (`ko`, `en`, `ja`, `zh`, `es`), Tailwind CSS 4, Vitest
- **Auth:** HttpOnly cookie access/refresh flow with Bearer header fallback, Kakao + Naver OAuth, auxiliary accounts, impersonation
- **PWA / Push:** service worker `frontend/public/sw.js` + `frontend/src/push/sw-runtime.ts`, VAPID web push, localized notification text, app badge

## 2. Hard Rules

### General

- Do not start dev servers (`./gradlew bootRun`, `npm run dev`) unless the user explicitly asks; the developer runs them.
- New configuration goes in `application.yml` with safe defaults; surface overrides through `.env.sample`.
- Prefer existing patterns over new structure. Read the nearest controller, service, view, and test first.
- For `gh` issues/PRs: skim recent ones to match conventions; write titles/bodies in English.

### Backend

- Constructor injection; service layer is `@Service` + `@Transactional`.
- Use the `logger()` extension from `common/config/LogbackConfig.kt`.
- Respect visibility/ownership gates: `FriendService`, `SchedulePermissionService`, `AttachmentPermissionEvaluator`, manager checks.
- Cookie auth and Bearer auth both exist. Before touching either path, check `JwtAuthFilter`, `CookieService`, auth controllers, and `frontend/src/api/client.ts`.
- API errors return machine-readable `code` values via `RestExceptionControllerAdvice`; user-facing translations live in frontend i18n bundles.
- Nightly cleanup jobs exist for refresh tokens, attachment sessions, notifications, and login attempts.

### Frontend

- `<script setup lang="ts">` for new SFCs.
- Authenticated HTTP goes in `frontend/src/api/*.ts`; shared interfaces in `frontend/src/types/index.ts`.
- `useSwal()` for confirmations and user-facing alerts.
- Auth is cookie-based via the shared Axios client. No access-token persistence in localStorage.
- All user-facing copy goes in `frontend/src/i18n/messages/*.ts` — no hardcoded strings in components, composables, or views. Keep all five locales in sync across UI copy, release notes, static notification templates, and service-worker text. For tight mobile slots (footer tabs, calendar cells, pills), add dedicated short keys instead of reusing desktop copy.
- Browser locale may drive first render or language suggestions, but it is not a confirmed preference until the user explicitly picks a language.
- Show language names in native form (`한국어`, `English`, `日本語`, `简体中文`, `Español`), untranslated.
- Style with Tailwind utilities and `--dp-*` tokens from `frontend/src/style.css`; no hardcoded hex or theme-blind utility colors. Inline `:style` only for runtime-dependent or CSS-variable-backed values.
- UI must work on mobile and desktop, in light and dark mode. Mobile checks: iPhone 16 Pro (402 x 874) and iPhone 13 mini (375 x 812) portrait.
- Interactive targets at least 44px, with visible hover/focus feedback.
- When visual quality or interaction polish matters, verify in the browser (Playwright) and iterate; static inspection alone is not enough.
- New user-facing routes: update both `frontend/src/router/index.ts` and `frontend/src/components/layout/AppHeader.vue`.

### Release Notes & `main` PRs

- Every human-authored PR to `main` needs exactly one release note entry, even docs/infra/maintenance. Dependabot-only dependency PRs are exempt.
- The note id needs the real PR number, so never guess it. Sequence: create a draft PR (`gh pr create --draft`) → commit a release note with `id: "pr-<number>"` to `frontend/src/releaseNotes/meta.ts` and every `frontend/src/releaseNotes/messages/*.ts` locale → push → `cd frontend && npm run release-notes:check` → run the requested build verification → `gh pr ready` → report CI for the head SHA.
- Date is the PR date in Asia/Seoul as `YYYY.MM.DD`, with `.02`, `.03`… for additional PRs on the same date.
- The `release-note` CI job skips draft PRs and gates merge. The GitHub Release is generated from the English in-app note — the PR body is not the release note source.

### Domain Gotchas

- Attachment contexts: `SCHEDULE`, `PROFILE`, `TEAM`, `TODO`. Changing them means updating enum, validation, storage path resolution, synchronization, cleanup, and storage layout together.
- Schedule create/update goes through `ScheduleTimeParsingQueueManager`; updates reset `ParsingTimeStatus` to `WAIT` and requeue parsing. Preserve this contract.
- The time parsing worker runs off-thread and saves entities explicitly — do not rely on JPA dirty checking there.
- Push subscription needs a valid refresh token cookie plus service worker registration; backend and frontend changes often move together.
- Notifications: unread polling with exponential backoff, friend-request counts, app badge updates. Keep these semantics aligned when touching notification UI or APIs.

## 3. Verification

- Backend: `./gradlew test` (or targeted `--tests`); API docs: `./gradlew asciidoctor`; full build: `./gradlew build` (includes asciidoctor)
- Frontend: `cd frontend && npm run type-check` and `npm run build`; `npm run test` for Vitest-covered stores/utils
- Release notes: `cd frontend && npm run release-notes:check`
- Local dev login for in-browser checks: `test@duty.park` / `12345678` (`http://localhost:5173`, backend `:8080`). Dev-only credentials, not real secrets.

## 4. Sub-Agents

- Use sub-agents when independent research, search, verification, or disjoint implementation can run in parallel; not for sequential steps, overlapping edits, or tightly coupled refactors.
- Use the same model as the main agent unless the user asks otherwise.

## 5. Collaboration

- Respond to the user in Korean.
- Ask short numbered questions only when ambiguity is risky.
- Favor backend-first changes for cross-cutting features.
- Work one checklist item at a time; stop and present the code after each item. RED -> GREEN -> REFACTOR where it fits.
- For design or visual decisions, show concrete options in the admin `관리 > 개발` tab (`/admin/dev`) so the user can compare in the product instead of choosing from chat descriptions.
- Never commit automatically.

## 6. Quick Pointers

- Noisy `frontend/dist/.gitkeep` deletions: `git update-index --assume-unchanged frontend/dist/.gitkeep`.
- If this file is not enough: `README.md`, `application*.yml`, and the nearest controller, view, or test.
