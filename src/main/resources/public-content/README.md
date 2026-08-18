# Public Content

`guide.json` and `release-notes.json` are the canonical content source for the web and iOS apps.
The backend loads and validates both files once at startup, then exposes localized public API responses.

- `GET /api/public-content/guide?locale=ko|en`
- `GET /api/public-content/release-notes?locale=ko|en&page=0&size=5`

Keep locale structures aligned and preserve item order. Do not author `contentVersion`; the backend returns
the canonical resource bytes' SHA-256 digest as `contentVersion` and uses it in the ETag automatically.
For release note authoring and validation, see `frontend/src/releaseNotes/README.md`.

## Guide visuals

`guide.json` has a top-level `visuals` object next to `schemaVersion` and `locales`. It is locale-independent:
keys are section ids, and each section's `cards` keys are card ids. The backend merges these into every
localized section and card, so `GuideSection` and `GuideCard` in the API response carry `icon` and `tone`.

```json
"visuals": {
  "dashboard": {
    "icon": "home",
    "tone": "accent",
    "cards": {
      "today": { "icon": "calendar", "tone": "accent" }
    }
  }
}
```

Both fields are closed vocabularies; clients own the mapping from a key to a native icon asset or color.

- `tone` (7): `accent`, `accentLight`, `success`, `warning`, `danger`, `neutral`, `muted`
- `icon` (25): `home`, `calendar`, `calendarCheck`, `building`, `settings`, `users`, `personAdd`, `userCog`,
  `pencil`, `spreadsheet`, `plus`, `sparkles`, `eye`, `checklist`, `search`, `palette`, `sun`, `bell`, `pin`,
  `trash`, `camera`, `shield`, `phone`, `link`, `lock`

Adding a section or card therefore requires adding its `visuals` entry, and removing one requires removing
the entry. Startup validation fails the application when a section/card has no visual, when `visuals` holds
an entry with no matching content, or when an `icon`/`tone` is outside the vocabularies above. Introducing a
new vocabulary key means updating `ICON_KEYS`/`TONE_KEYS` in `PublicContentService` and both client mapping
tables in the same change.
