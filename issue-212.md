# Issue 212 – Schedule Attachment Feature Specification

## Goals
- Allow users to attach multiple files to a schedule while reusing the same infrastructure for future domains (profile image, team cover, todo attachments).
- Persist attachments on local storage with configurable limits, blacklist, and thumbnail support.
- Enforce access control via Spring MVC so that attachment visibility follows the owning context (schedule, later others).

## Out of Scope
- External object storage (S3, NFS) integration.
- Virus scanning or content moderation.
- Non-image thumbnail generation (leave icon fallbacks to the UI).
- Mobile/Vue UI details beyond the API contract and lifecycle notes.

## Terminology
- **Attachment**: Persistent record describing a stored file and optional thumbnail.
- **Context**: Logical owner of an attachment (e.g., `SCHEDULE`, `PROFILE`). Each attachment has a `contextType` and `contextId`.
- **Upload Session**: Temporary grouping that allows files to be uploaded before the final owning entity exists (e.g., while creating a new schedule draft).

## Functional Requirements
- Users can upload N files per schedule (practical limit configurable in the future).
- Default maximum file size is 50 MB; value is configurable through application properties.
- Blacklist extensions are driven by configuration; files with blacklisted extensions are rejected with a descriptive error.
- Attachments can be uploaded, listed, downloaded, thumbnailed, and deleted via REST APIs.
- Upload workflow must support both creating new schedules and editing existing ones.
- On schedule deletion, all associated attachments and thumbnails must be removed from storage.
- API responses must expose enough metadata for UI rendering (original filename, size, MIME, createdAt, thumbnail availability).

## Non-Functional Requirements
- Storage path, file-size limit, and blacklist must be adjustable without code changes.
- Use UUID-based filenames to avoid collisions and mitigate path traversal risks.
- Ensure operations are transactional: database record creation should align with file persistence; cleanup on failure.
- Thumbnail generation should be pluggable to add new converters later (e.g., office docs).
- Logging should capture upload attempts, failures, and cleanup actions for observability.
- Attachment reads must be batch-friendly; repositories should support multi-context lookups to avoid N+1 queries when loading monthly schedule grids.
- On any persistence failure after the file has been written, immediately delete the orphaned file to keep storage clean.

## Data Model
```
Attachment
-----------
- id: UUID (primary key)
- contextType: enum AttachmentContextType (e.g., SCHEDULE, PROFILE, TEAM, TODO)
- contextId: String? (null while attachment is only tied to an upload session)
- uploadSessionId: UUID? (null once the attachment is bound to the real context)
- originalFilename: String
- storedFilename: String (UUID + ext)
- contentType: String
- size: Long (bytes)
- storagePath: String (relative to storage root)
- thumbnailFilename: String? (null if none)
- thumbnailContentType: String?
- thumbnailSize: Long?
- extraAttributes: JSON? (nullable; placeholder for domain-specific metadata)
- orderIndex: Int (0-based order per context; append new files to the end)
- createdBy: Long (member ID)
- createdAt: Instant

AttachmentUploadSession
-----------------------
- id: UUID
- contextType: AttachmentContextType (declares target domain)
- targetContextId: String? (e.g., existing schedule ID when editing)
- ownerId: Long (member initiating upload)
- expiresAt: Instant (cleanup job target)
- createdAt: Instant
```

Notes:
- `contextId` stored as `String` lets us support UUID-based IDs in future domains without schema changes.
- Prior to finalization, attachments keep `contextId = null` and `uploadSessionId = sessionId`. Once finalized, `uploadSessionId` becomes null and `contextId` is set to the owning entity ID.
- `extraAttributes` is optional but keeps the table extensible (e.g., storing image dimensions later).
- Add composite index `(contextType, contextId)` to enable efficient bulk fetches `WHERE context_type = ? AND context_id IN (...)`, plus an index on `uploadSessionId` for fast session lookups.

## Data Access Strategy
- `AttachmentRepository` exposes `findAllByContextTypeAndContextIdIn(AttachmentContextType, Collection<String>)` so services can fetch attachments for a month’s schedules in one query.
- Schedule listings should load schedules first, then call the repository method and group results by `contextId` in memory.
- Optional JPA `@OneToMany` mappings can be provided for convenience, but bulk endpoints must rely on the dedicated repository call to avoid N+1 issues.

## Storage Layout
- Configurable root: `dutypark.storage.root` (default `storage/` relative to project root).
- Directory pattern: `{root}/{contextType}/{contextId}/`.
- Temporary uploads live under `{root}/_tmp/{sessionId}/` until the session is finalized.
- Filenames use `storedFilename` (UUID + original extension). Thumbnails prepend `thumb-` followed by the base UUID and `.png` (generated for supported image formats only).
- On finalization, files move from `_tmp` to the permanent context directory atomically.

## Configuration
Example `application.yml` snippet:
```yaml
dutypark:
  storage:
    root: storage
    max-file-size: 50MB
    blacklist-ext:
      - exe
      - bat
      - cmd
      - sh
      - js
    thumbnail:
      max-side: 200
```
- `blacklist-ext` should be case-insensitive in enforcement.
- `max-file-size` reused by multipart resolver limits to avoid redundant validation.
- `thumbnail.max-side` defines the longest edge for generated image thumbnails.

## API Design
- `POST /api/attachments/sessions`
  - Request: `{ "contextType": "SCHEDULE", "targetContextId": "<optional scheduleId when editing>" }`
  - Response: `{ "sessionId": "...", "expiresAt": "...", "contextType": "SCHEDULE" }`
- `POST /api/attachments` (multipart)
  - Params: `sessionId` (required), `file`
  - Response: attachment DTO with generated ID (including provisional `orderIndex`); returns HTTP 413 if size exceeds limit or 400 when extension is blocked.
- `POST /api/attachments/sessions/{sessionId}/finalize`
  - Request: `{ "contextId": "<scheduleId>", "orderedAttachmentIds": ["..."] }`
  - Rebinds all attachments with `uploadSessionId=sessionId` so they belong to the schedule and recalculates `orderIndex` following the provided order (appends any missing IDs to the end).
- `POST /api/attachments/reorder`
  - Request: `{ "contextType": "SCHEDULE", "contextId": "<scheduleId>", "orderedAttachmentIds": ["..."] }`
  - Updates ordering for existing attachments without creating a new session (supports drag & drop).
- `GET /api/schedules/{id}/attachments`
  - Returns list of attachment DTOs filtered by `contextType=SCHEDULE` and `contextId=scheduleId`.
- `DELETE /api/attachments/{id}`
  - Removes a single attachment when the caller has write permission.
- `GET /api/attachments/{id}/download`
  - Streams the original file; requires read permission on owning context.
- `GET /api/attachments/{id}/thumbnail`
  - Streams thumbnail if available; otherwise 404.

DTO fields (draft):
```
{
  "id": "UUID",
  "contextType": "SCHEDULE",
  "contextId": "12345",
  "originalFilename": "meeting.pdf",
  "contentType": "application/pdf",
  "size": 473829,
  "hasThumbnail": true,
  "thumbnailUrl": "...",
  "orderIndex": 0,
  "createdAt": "2025-03-10T12:34:56Z",
  "createdBy": 42
}
```

## Error Handling
- Blocked extensions return HTTP 400 with error code `ATTACHMENT_EXTENSION_BLOCKED`.
- Files exceeding `max-file-size` return HTTP 413 with code `ATTACHMENT_TOO_LARGE`.
- Requests referencing unknown attachments return HTTP 404.
- Permission failures (download/delete/finalize) return HTTP 403.
- Finalizing a session with a `contextId` that differs from the session’s `targetContextId` returns HTTP 409 with code `ATTACHMENT_FINALIZE_MISMATCH`.

## Upload Workflow
1. Front-end requests a session before the schedule is saved. When editing an existing schedule, the session request includes `targetContextId` so the backend can verify write permission.
2. Files upload individually with the session ID. Server validates blacklist & size, writes to `_tmp`, creates `Attachment` with `uploadSessionId=sessionId` and `contextId=null`.
3. When the schedule is persisted or updated, the client submits the session ID along with the final `orderedAttachmentIds` (existing + new IDs). Backend binds new attachments to the schedule, moves files into the permanent directory, and updates `orderIndex` to match the provided order; any attachments omitted from the list keep their relative order but are appended after the listed ones.
4. Existing attachments are deleted by calling `DELETE /api/attachments/{id}` per file; they do not flow through sessions.
5. If the user cancels, an asynchronous cleanup job removes expired sessions and their files.

## Thumbnail Generation
- Provide `ThumbnailService` with strategy interface `ThumbnailGenerator` and concrete implementations:
  - `ImageThumbnailGenerator` (JPEG/PNG/WEBP, etc.) using `Thumbnailator` or `imgscalr`.
- Generate thumbnails synchronously on upload; failures should not break the upload but log warnings.
- Store thumbnails as PNG 200×200 (fit within max side while preserving aspect ratio).
- Record thumbnail metadata on the `Attachment` record for easy detection.
- Future formats can register additional generators and advertise capabilities through configuration.
- PDF thumbnails are not generated by default to avoid heavy dependencies; support can be added later with another `ThumbnailGenerator`.

## Security & Permissions
- `AttachmentPermissionEvaluator` resolves access by delegating to the owning context service (e.g., `ScheduleService.hasReadPermission(memberId, scheduleId)`).
- Upload operations require the same permissions as editing the target context; sessions store `ownerId` and reject binding by other users.
- When creating a session with `targetContextId`, verify that the requester can write to that schedule before issuing the session to prevent unauthorized uploads.
- Download/thumbnail endpoints check read permission before streaming.
- Ensure path handling prevents directory traversal by restricting to computed directories.

## Cleanup & Maintenance
- Upload sessions default to a 24 hour lifetime; `expiresAt` is stored per session.
- A daily scheduled job (e.g., 02:00 server time) purges:
  - Upload sessions past `expiresAt` (deletes DB rows and `_tmp` directories).
  - Attachments whose context entity no longer exists (defensive sweep).
- If a cleanup operation fails (e.g., file lock), log the error and let the next scheduled run retry automatically.
- When deleting a schedule, cascade deletion of attachments (service layer ensures file removal + DB delete).
- On application startup, optional sanity check can verify storage root exists and is writable.

## UI & Integration Notes
- Vue components should display inline upload progress per file, allow removal before final save, and render thumbnails/icons.
- REST Docs: add snippets for session creation, file upload, list, download, delete.
- For editing schedules, server should return existing attachment DTOs so the front-end can pre-populate and reconcile with session uploads.
- UI should send `orderedAttachmentIds` on finalize/reorder to persist user-defined ordering; default ordering is ascending `orderIndex`.

## Implementation Plan

### Backend (TDD Sequence)
- [ ] Introduce `dutypark.storage` configuration properties with validation and unit tests for property binding/defaults.
- [ ] Add Flyway migrations creating `attachment` and `attachment_upload_session` tables plus indexes; cover with migration smoke test using the existing in-memory database profile.
- [ ] Define domain types (`Attachment`, `AttachmentUploadSession`, `AttachmentContextType`, DTO mappers) with Kotlin data/Entity classes and unit tests for mapping.
- [ ] Implement `AttachmentRepository` and multi-context lookup query methods; cover with Spring Data JPA slice tests ensuring no N+1.
- [ ] Build blacklist/size validation service that reads from configuration; write unit tests covering acceptance/rejection cases.
- [ ] Implement storage path resolver & file system service handling write/delete/move with rollback on failure; cover via temporary filesystem tests.
- [ ] Create image-only `ThumbnailService` (`ThumbnailGenerator` + implementation) with unit tests ensuring 200x200 constraint and graceful failure logging.
- [ ] Develop `AttachmentUploadSessionService` and `AttachmentService` (create, finalize, reorder, delete) using TDD-focused service tests mocking storage/thumbnail components.
- [ ] Wire permission checks through a dedicated evaluator; write unit tests ensuring context delegation and session ownership enforcement.
- [ ] Expose REST controllers (`AttachmentSessionController`, `AttachmentController`) with MockMvc tests for upload, finalize, reorder, list, download, delete, thumbnail endpoints including error cases.
- [ ] Integrate schedule deletion cascade through domain service/event listener; add integration test ensuring files removed from disk and DB.
- [ ] Implement scheduled cleanup job with clock injection; write integration test asserting expired sessions/attachments removed.
- [ ] Update REST Docs snippets for all new endpoints; ensure asciidoctor build passes.

### Frontend (After Backend Completion)
- [ ] Add storage config to environment layer (API base paths, size limit messaging).
- [ ] Implement attachment API client functions (create session, upload, finalize, reorder, delete, download URL helpers).
- [ ] Extend schedule create/edit Vue store to manage upload sessions and maintain ordered attachment lists.
- [ ] Update form components to support multi-file upload with progress, blacklist/size error surfacing, and single-file delete.
- [ ] Render thumbnails/icons within schedule views and modals; ensure 200px constraints and fallback icons for non-image types.
- [ ] Add attachment ordering UI (drag/drop or control buttons) propagating `orderedAttachmentIds` to finalize/reorder calls.
- [ ] Cover new logic with unit tests (Vue component tests, store tests) and, if applicable, Cypress/e2e scenario for create/edit with attachments.
- [ ] Update user-facing documentation/help text explaining attachment support and limits.
