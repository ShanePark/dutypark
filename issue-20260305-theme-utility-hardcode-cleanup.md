# Theme Utility Hardcode Cleanup Plan (2026-03-05)

## Goal
- Replace hardcoded color/style values that can be expressed as `dp-*` token utility classes.
- Preserve dark-mode readability and existing behavior.
- Validate all routes in light/dark mode with Playwright screenshots.

## Baseline
- Last committed baseline: `c4e67541` (`fix: restore dark-mode contrast with on-dark text tokens`)
- Existing token policy:
1. `text-dp-text-inverse`: mode-inverted text only.
2. `text-dp-text-on-dark`: text on dark/strong/overlay surfaces.
3. Visibility color policy: `FRIENDS=accent`, `FAMILY=warning`.

## Scope
- Frontend only (`frontend/src/**`).
- Focus on **hardcoded values** (`#hex`, `rgb/rgba`, literal `white/black`) that are replaceable with token utilities.
- Keep functional logic unchanged.

## Out of Scope
- Full redesign of intro/marketing visual language where custom gradients are intentional.
- Non-color numeric animation tuning unless required for readability regressions.

## RED (Detection & Failure Definition)
### Failure Conditions
1. Hardcoded foreground/background colors in component/view templates/styles where `dp-*` token utility is possible.
2. `text-white`/literal white usage on non-dark contexts.
3. Overlay/dark-surface text not using `text-dp-text-on-dark`.

### Detection Commands
```bash
rg -n --glob 'frontend/src/**/*.{vue,ts,css}' "#[0-9a-fA-F]{3,8}|rgba?\(|hsla?\(|\bwhite\b|\bblack\b"
rg -n --glob 'frontend/src/**/*.{vue,ts}' "text-(white|black)|bg-(white|black)|border-(white|black)|style=\"|:style="
```

## GREEN (Implementation Checklist)

### Item 1. Shared token utilities foundation
- [x] Add/extend utility classes in `frontend/src/style.css` for repeated on-dark text and overlay helper patterns.
- [x] Add concise policy comments (`inverse` vs `on-dark` usage rules).
- [x] Ensure utilities support both light/dark without per-component hardcoding.

### Item 2. Core app shell and global overlays
- [x] Replace hardcoded color literals in common shell components (`layout`, `common` overlays/viewers/guides where applicable).
- [x] Convert inline literal color styles to class-based token utilities.
- [x] Keep z-index/spacing behavior unchanged.

### Item 3. Duty/Team/Dashboard surface cleanup
- [x] Replace hardcoded text/border fallback literals in duty/team/dashboard components/views.
- [x] Use tokenized on-dark text for dynamic strong-color chips/cards.
- [x] Keep dynamic `isLightColor(...)` logic only where necessary.

### Item 4. Auth/Policy/Admin residual hardcoded cleanup
- [x] Remove remaining literal color values in auth/policy/admin files that can map to utilities.
- [x] Reduce repetitive `:style` blocks by utility classes where static.
- [x] Preserve existing responsive/layout behavior.

### Item 5. Residual scan + allowlist finalization
- [x] Re-run detection commands.
- [x] Keep only intentional literals (e.g., visual brand gradients) in explicit allowlist notes.
- [x] Document residuals and rationale.

#### Residual Allowlist (final)
- `frontend/src/components/common/FileUploader.vue`: `white-space` token in CSS property name (not a color literal).
- `frontend/src/components/intro/IntroShowcase.vue`: `white-space` token in CSS property name (not a color literal).

## REFACTOR
- [x] Normalize repeated class bundles into reusable utility classes when repeated 3+ times.
- [x] Remove dead style blocks introduced by prior migrations.
- [x] Keep comments minimal and English-only.

## Verification Checklist

### Static
- [x] `cd frontend && npm run type-check`
- [x] `cd frontend && npm run build`
- [x] `rg` residual hardcoded scan reviewed and classified

### Playwright Visual Sweep
- [x] Guest routes light/dark screenshots
- [x] Auth routes light/dark screenshots
- [x] Compare against baseline (`c4e67541`) with diff report
- [x] Manual spot-check of top-diff pages for readability regressions

## Acceptance Criteria
1. Replaceable hardcoded color literals are converted to token utility usage.
2. Dark-mode readability remains intact on all major routes.
3. Type-check/build pass.
4. Residual literals are intentional and documented.

## Execution Log
- [x] Item 1 complete
- [x] Item 2 complete
- [x] Item 3 complete
- [x] Item 4 complete
- [x] Item 5 complete
- [x] Verification complete

### Artifacts
- Visual compare root: `/tmp/dutypark-visual-compare-20260305-145528-hardcode2`
- Current screenshots: `/tmp/dutypark-visual-compare-20260305-145528-hardcode2/current`
- Baseline screenshots: `/tmp/dutypark-visual-compare-20260305-145528-hardcode2/baseline`
- Diff report: `/tmp/dutypark-visual-compare-20260305-145528-hardcode2/report.tsv`
- Top diff summary: `/tmp/dutypark-visual-compare-20260305-145528-hardcode2/top20.tsv`
