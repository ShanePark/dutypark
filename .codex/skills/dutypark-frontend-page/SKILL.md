---
name: dutypark-frontend-page
description: Add or update Dutypark Vue pages, routes, layout navigation, and theme-safe UI patterns. Use when creating or modifying view-level components in frontend/src, wiring Vue Router routes, deciding AppHeader menu entries, or validating Tailwind and CSS token conventions in this repository.
---

# Dutypark Frontend Page

Assume the current working directory is the Dutypark repository root and the target code lives under `frontend/`.

## Workflow

1. Inspect the existing route, view, API module, store, and nearby components before editing. Dutypark frontend work is usually incremental, not greenfield.
2. For a new page or route:
   - Add or update the route in `frontend/src/router/index.ts`.
   - Decide `requiresAuth`, `guestOnly`, and `requiresAdmin` from existing route conventions.
   - Check whether logged-in users need direct navigation from `frontend/src/components/layout/AppHeader.vue`.
3. Keep page logic in `<script setup lang="ts">`. Use API wrappers from `frontend/src/api/*.ts`, shared types from `frontend/src/types/index.ts`, and `useSwal()` for confirmations or user-facing alerts.
4. Style with Tailwind 4 plus `--dp-*` tokens from `frontend/src/style.css`. Prefer reusable classes and token-backed colors over hardcoded palette values.
5. Use inline `:style` only when the value is runtime-dependent or already token-based, such as dynamic duty colors or CSS variable application already common in this codebase.
6. Preserve mobile-first behavior, visible hover or focus feedback, and minimum 44px interactive targets.
7. Verify with `cd frontend && npm run type-check` and `cd frontend && npm run build`. Run `cd frontend && npm run test` when touching existing Vitest-covered stores or utils, or when adding new unit-level logic.

## Dutypark-Specific Notes

- Auth is cookie-based. `frontend/src/api/client.ts` handles refresh and impersonation edge cases. Do not add localStorage token persistence.
- Theme tokens, fonts, and semantic color aliases live in `frontend/src/style.css`.
- Notification polling, backoff, and app badge behavior live in `frontend/src/stores/notification.ts`.
- Current route entry points are concentrated in:
  - `frontend/src/views/dashboard`
  - `frontend/src/views/duty`
  - `frontend/src/views/member`
  - `frontend/src/views/team`
  - `frontend/src/views/todo`
  - `frontend/src/views/admin`

## Guardrails

- Do not add a user-facing route without reviewing whether `AppHeader.vue` should expose it.
- Do not introduce hardcoded theme colors for surfaces, borders, or text when a `--dp-*` token already exists.
- Do not bypass the shared API client for authenticated HTTP calls unless there is a clear reason.
