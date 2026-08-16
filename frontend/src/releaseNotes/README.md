# Release Notes

Release notes are shown in `/guide` under the changelog section. Their single source of truth is
`src/main/resources/public-content/release-notes.json` at the repository root.

When preparing a human-authored PR that targets `main`:

1. Create the PR first so the PR number is known.
2. Add one metadata item to `release-notes.json` with `id: "pr-<number>"`.
3. Use the PR date in Asia/Seoul as the version: `YYYY.MM.DD`.
4. If multiple PRs share a date, keep the first as `YYYY.MM.DD` and append `.02`, `.03`, and so on.
5. Add the same entry id under both `locales.en.entries` and `locales.ko.entries`.
6. Run `npm run release-notes:check` and `npm run type-check`.

Do not add or edit a `contentVersion` field. The backend derives the API `contentVersion` and ETag
automatically from the canonical JSON file's SHA-256 digest.

Dependabot-only dependency update PRs are exempt from in-app release notes.

The PR CI checks the current PR number explicitly with `.github/scripts/check-pr-release-note.mjs`.
If the `pr-<number>` metadata or locale copy is missing, the PR should fail before review or merge.

The release note checker validates JSON syntax, metadata uniqueness and ordering, supported labels,
and exact entry parity across both locales.

GitHub Releases are created only for future human-authored merges. The `GitHub Release` workflow creates a date-based release from the `main` merge commit. It resolves the merged PR, skips Dependabot-only dependency update PRs, reads the matching English in-app release note entry for other PRs, and uses that same content for the GitHub Release body. If the metadata or English copy is missing, the workflow fails instead of publishing a different release note.

If a release ever needs to be retried, run the workflow manually with `workflow_dispatch` and the merged PR number.
