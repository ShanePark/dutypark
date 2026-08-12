# Dutypark – Agent Operations Manual

Repo-wide defaults only. Read the code, nearby tests, and linked documentation for details instead of expanding this file.

## 1. Stack

- **Backend:** Kotlin, Java 25, Spring Boot 4, MySQL 8.0
- **AI:** Spring AI OpenAI-compatible Google Generative Language client; queue-based schedule time parsing
- **Web:** Vue 3, Vite, TypeScript, Pinia, Vue Router, Vue I18n (`ko`, `en`, `ja`, `zh`, `es`), Tailwind CSS 4, Vitest
- **iOS:** Swift 6, SwiftUI, iOS 17+
- **Auth / Push:** HttpOnly access/refresh cookies with Bearer fallback, Kakao/Naver OAuth, auxiliary accounts, impersonation, VAPID web push

## 2. Hard Rules

### General

- Do not start dev servers (`./gradlew bootRun`, `npm run dev`) unless the user explicitly asks; the developer runs them. Put new configuration in `application.yml` with safe defaults and surface overrides through `.env.sample`.
- Prefer existing patterns over new structure. Read the nearest controller, service, view, and test first.
- For `gh` issues/PRs, skim recent examples and write titles and bodies in English.

### Backend

- Use constructor injection; services are `@Service` + `@Transactional`; logging uses `logger()` from `common/config/LogbackConfig.kt`.
- Preserve visibility and ownership gates (`FriendService`, `SchedulePermissionService`, `AttachmentPermissionEvaluator`, manager checks). Before changing authentication, inspect `JwtAuthFilter`, `CookieService`, auth controllers, and `frontend/src/api/client.ts`; cookie and Bearer paths must both keep working.
- API errors expose machine-readable `code` values through `RestExceptionControllerAdvice`; user-facing translations belong in frontend i18n bundles.

### Frontend

- New SFCs use `<script setup lang="ts">`; authenticated HTTP belongs in `frontend/src/api/*.ts`, shared interfaces in `frontend/src/types/index.ts`, and confirmations/alerts use `useSwal()`.
- Authentication uses the shared cookie-based Axios client; never persist access tokens in localStorage.
- Put all user-facing copy in every `frontend/src/i18n/messages/*.ts` locale, including release notes, static notifications, and service-worker text. Use dedicated short keys for tight mobile slots. Browser locale is not a confirmed preference until explicitly selected; show language names natively.
- Use Tailwind and `--dp-*` tokens from `frontend/src/style.css`; no hardcoded hex or theme-blind colors. Inline `:style` is only for runtime-dependent or CSS-variable-backed values.
- Support mobile and desktop, light and dark mode, and 44px interaction targets with visible hover/focus feedback. Check iPhone 16 Pro (402×874) and iPhone 13 mini (375×812); verify visual polish in the browser with Playwright.
- New user-facing routes must update both `frontend/src/router/index.ts` and `frontend/src/components/layout/AppHeader.vue`.

### Release Notes & `main` PRs

- Every human-authored PR to `main` needs exactly one release note; Dependabot-only dependency PRs are exempt. Follow `frontend/src/releaseNotes/README.md` for ids, dates, locales, and checks.
- Create a draft PR first to obtain the real number, add and push `pr-<number>` release-note entries, run `cd frontend && npm run release-notes:check` and requested verification, mark the PR ready, then report CI for the head SHA. Never guess the PR number.

### Domain Gotchas

- Attachment contexts (`SCHEDULE`, `PROFILE`, `TEAM`, `TODO`) must change across enum, validation, storage paths, synchronization, cleanup, and storage layout together.
- Schedule create/update must use `ScheduleTimeParsingQueueManager`; updates reset `ParsingTimeStatus` to `WAIT` and requeue. The off-thread worker saves entities explicitly and must not rely on JPA dirty checking.
- Web/PWA and native iOS authentication and push paths coexist. Web push subscription requires a valid refresh-token cookie and service-worker registration. Regression-test every affected client after shared backend changes, preserving unread polling backoff, friend-request counts, and app-badge semantics.

## 3. Verification

- Backend: `./gradlew test` (or targeted `--tests`); API docs: `./gradlew asciidoctor`; full build: `./gradlew build`
- Frontend: `cd frontend && npm run type-check && npm run build`; run `npm run test` for Vitest-covered stores and utilities
- iOS: run the documented simulator `xcodebuild ... build` and `xcodebuild ... test` commands from `ios/README.md`
- Release notes: `cd frontend && npm run release-notes:check`
- Browser login: `test@duty.park` / `12345678` at `http://localhost:5173` with backend `:8080` (dev-only credentials)

## 4. Agent Roles, Delegation, and Parallelism

These rules are required, not advisory.

### Role separation

- The main agent is the orchestrator: it performs discovery, design, planning, decomposition, coordination, and review. It does not write or edit implementation code directly.
- Delegate every implementation change to a sub-agent regardless of size; there is no small-change exception. Use the main agent's model unless the user asks otherwise.
- Sequential or tightly coupled implementation is still delegated to one sub-agent at a time. Parallelism controls concurrency, not whether implementation is delegated.

### Task briefs and ownership

- Give each sub-agent a bounded brief naming target files, expected deliverables, constraints, and verification commands or observable results.
- Run independent work on disjoint files in parallel; do not parallelize overlapping edits or ordering dependencies.
- Assign one owner to shared files such as manifests, lockfiles, routing/registration, migrations, release-note registries, and this file.
- For cross-cutting work, establish shared contracts first, then fan out only work that lands in independent files.

### Review and handover

- Sub-agents report changed files, verification, assumptions, and remaining risks when a unit finishes.
- The main agent reviews correctness, scope, simplicity, unrelated edits, and missing tests. Return deficiencies to the implementing sub-agent instead of fixing them directly.
- The main agent performs final integration and shared-resource verification after delegated work completes.

## 5. Collaboration

- Respond in Korean and ask short numbered questions only when ambiguity is risky.
- Favor backend-first changes for cross-cutting features. Coordinate one coherent checklist unit at a time and present reviewed delegated results to the user.
- Show visual/design options in `관리 > 개발` (`/admin/dev`) for in-product comparison.
- Never commit automatically.
