---
name: dutypark-playwright-ui
description: Verify complex Dutypark UI flows with Playwright MCP. Use when static inspection and normal build checks are insufficient, especially for drag-and-drop, multi-step modal flows, notifications or push UX, OAuth redirects, or visual regressions in this repository. Assume the developer has already started the backend and Vite dev servers; do not start them yourself.
---

# Dutypark Playwright UI

Use this skill only for flows that are hard to validate confidently without a browser.

## When to Use It

- SortableJS drag-and-drop behavior in duty or todo flows
- Multi-step modal chains in duty, team, member, or attachment workflows
- Notification dropdown or list synchronization
- OAuth callback or SSO onboarding flows
- Responsive regressions or theme regressions that need visual confirmation

Skip Playwright for straightforward CRUD, simple styling tweaks, or changes already covered by targeted tests and builds.

## Workflow

1. Assume local frontend is available at `http://localhost:5173` and proxies backend requests to `:8080`.
2. Never start `./gradlew bootRun` or `cd frontend && npm run dev` yourself.
3. Sign in with the local development account when authentication is required:
   - Email: `test@duty.park`
   - Password: `12345678`
4. Exercise the smallest realistic flow that proves the change.
5. Inspect both the visible result and browser failures. Check console and network requests when the UI behavior is ambiguous.
6. If the flow mutates data, clean up when practical or state clearly what test data was left behind.

## Dutypark-Specific Notes

- Push flows may require service worker registration and browser permission prompts. Verify `frontend/public/sw.js`, the push composable, and `/api/auth/push/*` endpoints together when debugging.
- Notification behavior combines dropdown UI, polling, unread counts, friend request counts, and app badge updates.
- OAuth callbacks are routed through `/auth/oauth-callback` on the SPA and `/api/auth/Oauth2ClientCallback/*` on the backend.

## Guardrails

- Report blockers exactly if the dev servers are unavailable or local credentials stop working.
- Prefer code-path verification over brittle full OAuth automation when a provider redirect cannot be completed locally.
