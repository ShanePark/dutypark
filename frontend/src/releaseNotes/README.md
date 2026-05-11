# Release Notes

Release notes are shown in `/guide` under the changelog section.

When a PR is merged:

1. Add one metadata entry to `meta.ts`.
2. Use the PR merge date in Asia/Seoul as the version: `YYYY.MM.DD`.
3. If multiple PRs share a date, keep the first as `YYYY.MM.DD` and append `.02`, `.03`, and so on in merge-time order.
4. Add the same entry id to every file in `messages/`.
5. Run `npm run release-notes:check` and `npm run type-check`.

The `ReleaseNotesMessages<ReleaseNoteId>` type intentionally fails type-checking when a locale is missing a PR entry.
