# Public Content

`guide.json` and `release-notes.json` are the canonical content source for the web and iOS apps.
The backend loads and validates both files once at startup, then exposes localized public API responses.

- `GET /api/public-content/guide?locale=ko|en`
- `GET /api/public-content/release-notes?locale=ko|en&page=0&size=5`

Keep locale structures aligned and preserve item order. Do not author `contentVersion`; the backend returns
the canonical resource bytes' SHA-256 digest as `contentVersion` and uses it in the ETag automatically.
For release note authoring and validation, see `frontend/src/releaseNotes/README.md`.
