# Release Notes

Release notes are shown in `/guide` under the changelog section.

When preparing a PR that targets `main`:

1. Create the PR first so the PR number is known.
2. Add one metadata entry to `meta.ts` with `id: "pr-<number>"`.
3. Use the PR date in Asia/Seoul as the version: `YYYY.MM.DD`.
4. If multiple PRs share a date, keep the first as `YYYY.MM.DD` and append `.02`, `.03`, and so on.
5. Add the same entry id to every file in `messages/`.
6. Run `npm run release-notes:check` and `npm run type-check`.

The PR CI checks the current PR number explicitly with `.github/scripts/check-pr-release-note.mjs`.
If the `pr-<number>` metadata or locale copy is missing, the PR should fail before review or merge.

The `ReleaseNotesMessages<ReleaseNoteId>` type intentionally fails type-checking when a locale is missing a PR entry.

GitHub Releases are created only for future merges. The `GitHub Release` workflow creates a date-based release from the `main` merge commit. It resolves the merged PR, reads the matching English in-app release note entry, and uses that same content for the GitHub Release body. If the metadata or English copy is missing, the workflow fails instead of publishing a different release note.

If a release ever needs to be retried, run the workflow manually with `workflow_dispatch` and the merged PR number.
