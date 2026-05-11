# Release Notes

Release notes are shown in `/guide` under the changelog section.

When preparing a PR:

1. Add one metadata entry to `meta.ts`.
2. Use the PR date in Asia/Seoul as the version: `YYYY.MM.DD`.
3. If multiple PRs share a date, keep the first as `YYYY.MM.DD` and append `.02`, `.03`, and so on.
4. Add the same entry id to every file in `messages/`.
5. Run `npm run release-notes:check` and `npm run type-check`.

The `ReleaseNotesMessages<ReleaseNoteId>` type intentionally fails type-checking when a locale is missing a PR entry.

GitHub Releases are created only for future merges. The `GitHub Release` workflow creates a date-based release when a PR is merged into `main`. It reads the matching English in-app release note entry and uses that same content for the GitHub Release body. If the metadata or English copy is missing, the workflow fails instead of publishing a different release note.

If the first merge that introduces the workflow does not run automatically, run the workflow manually with `workflow_dispatch` and the merged PR number.
