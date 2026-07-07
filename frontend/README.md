# Dutypark Frontend

Vue 3 SPA for Dutypark. The frontend is Vite-based, cookie-authenticated through the shared backend client, localized, and installable as a PWA with web push support.

## Tech Stack

| Category | Technology |
|----------|------------|
| Framework | Vue 3 with `<script setup lang="ts">` |
| Build | Vite + `@vitejs/plugin-vue` |
| Language | TypeScript |
| State | Pinia |
| Routing | Vue Router |
| Localization | Vue I18n (`ko`, `en`, `ja`, `zh`, `es`) |
| Styling | Tailwind CSS 4 + `--dp-*` design tokens |
| Tests | Vitest |
| UI helpers | Lucide Vue, SweetAlert2, Uppy, SortableJS, Pickr |

## Quick Start

```bash
npm install
npm run dev
npm run type-check
npm run build
npm run test
```

The dev server runs on `http://localhost:5173` and proxies `/api`, `/admin/api`, `/logout`, and `/docs` to the backend on `http://localhost:8080`.

## Environment

| Variable | Purpose |
|----------|---------|
| `VITE_API_BASE_URL` | Optional absolute backend base URL for OAuth redirects; defaults to `window.location.origin` |
| `VITE_KAKAO_APP_KEY` | Kakao JavaScript SDK app key |
| `VITE_NAVER_CLIENT_ID` | Naver OAuth client ID exposed to the browser |

Vite reads these values from `frontend/.env.development`, `frontend/.env.production`, or process environment. Backend OAuth credentials and shared deployment variables live in the root `.env.sample`.

## Project Structure

```
src/
├── api/           # Axios API modules; authenticated calls use the shared cookie client
├── components/    # Common UI, layout, duty, team, todo, admin, and intro components
├── composables/   # useSwal, useKakao, useNaver, usePushNotification, and UI helpers
├── stores/        # auth, notification polling/badge state, theme, locale
├── views/         # Route-level pages for dashboard, duty, todo, member, team, admin, guide, policy
├── i18n/          # Locale utilities and message bundles
├── notifications/ # Static notification rendering helpers for push/service worker contexts
├── push/          # Service worker runtime and push presentation helpers
├── releaseNotes/  # In-app changelog metadata and localized release copy
├── router/        # Route definitions and auth/admin guards
├── types/         # Shared TypeScript DTOs and UI types
└── utils/         # Date, visibility, redirect, notification, and push utilities
```

## Auth And API

`src/api/client.ts` owns the shared Axios instance:

- Base URL is `/api`.
- `withCredentials: true` sends HttpOnly access/refresh cookies.
- 401 responses queue while `/auth/refresh` is attempted.
- The SPA does not persist access tokens in `localStorage`.
- Backend Bearer-token fallback still exists for non-SPA clients.

Kakao and Naver login/link flows live in `useKakao.ts` and `useNaver.ts`. Both build backend OAuth callback URLs from `VITE_API_BASE_URL` or the current origin.

## Routes

| Path | Auth | Description |
|------|------|-------------|
| `/` | Optional | Dashboard |
| `/auth/login` | Guest only | Login page |
| `/auth/oauth-callback` | Public | OAuth redirect handler |
| `/auth/sso-signup` | Public | SSO signup |
| `/auth/sso-congrats` | Required | Post-signup page |
| `/duty/:id` | Optional | Duty calendar |
| `/todo` | Required | Kanban todo board |
| `/member` | Required | Profile and settings |
| `/friends` | Required | Friends and relationship requests |
| `/team` | Required | Team calendar |
| `/team/manage/:teamId` | Required | Team management |
| `/notifications` | Required | Notification list |
| `/admin` | Admin | Admin dashboard |
| `/admin/teams` | Admin | Admin team list |
| `/admin/dev` | Admin | Development playground |
| `/guide` | Public | Product guide and changelog |
| `/terms`, `/privacy` | Public | Policy pages |

When adding a user-facing route, update both `src/router/index.ts` and `src/components/layout/AppHeader.vue` when the route should be discoverable from navigation.

## Localization

User-facing copy belongs in `src/i18n/messages/*.ts`. Supported locale files are `ko`, `en`, `ja`, `zh`, and `es`; keep them synchronized with release-note copy and static notification templates. Language names are shown in their native forms through `localeUtils.ts`.

The locale store separates detected browser locale from explicit user choice and syncs the active locale to the service worker for localized push notifications.

## PWA And Push

`public/sw.js` imports `src/push/sw-runtime.ts` during development. The production build emits `sw-runtime.js` through Vite rollup input configuration.

The service worker handles install/activate, push presentation, notification-click routing, locale cache, and app badge updates. It does not currently implement app-shell or fetch-response offline caching.

## Release Notes

Main-targeting PRs require exactly one in-app release note entry after the PR number is known. Update `src/releaseNotes/meta.ts` and every file under `src/releaseNotes/messages/`, then run:

```bash
npm run release-notes:check
```

The `release-note` CI job validates the PR number explicitly, and the GitHub Release workflow publishes from the matching English in-app release note after merge.
