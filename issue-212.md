# Issue 212 – Schedule Attachment Feature Specification

## Development Workflow
- **Work on ONE checklist item at a time** - never attempt multiple checklist items simultaneously.
- Break each checklist item into smaller, manageable todos (typically 3-5 todos per checklist item).
- Keep individual todos small to prevent work from going off track.
- Complete all todos for the current checklist item before moving to the next.
- **After completing all todos for a checklist item, STOP and present the code for user review.**
- **NEVER commit automatically** - wait for explicit user instruction like "commit this" or "커밋해줘".
- Only move to the next checklist item after user confirms the current work and explicitly requests commit.

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
- orderIndex: Int (0-based order per context; append new files to the end)
- createdBy: Long (member ID)
- createdDate: LocalDateTime (inherited from EntityBase)
- modifiedDate: LocalDateTime (inherited from EntityBase)

AttachmentUploadSession
-----------------------
- id: UUID
- contextType: AttachmentContextType (declares target domain)
- targetContextId: String? (e.g., existing schedule ID when editing)
- ownerId: Long (member initiating upload)
- expiresAt: Instant (cleanup job target)
- createdDate: LocalDateTime (inherited from EntityBase)
- modifiedDate: LocalDateTime (inherited from EntityBase)
```

Notes:
- `contextId` stored as `String` lets us support UUID-based IDs in future domains without schema changes.
- Prior to finalization, attachments keep `contextId = null` and `uploadSessionId = sessionId`. Once finalized, `uploadSessionId` becomes null and `contextId` is set to the owning entity ID.
- Both entities inherit from `EntityBase`, providing UUID primary key with ULID generation, and automatic `createdDate`/`modifiedDate` audit fields.
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

## Frontend API Reference

### Available Endpoints

#### 1. Create Upload Session
**Endpoint:** `POST /api/attachments/sessions`

**Request:**
```json
{
  "contextType": "SCHEDULE",
  "targetContextId": "12345"  // optional, required when editing existing schedule
}
```

**Response:**
```json
{
  "sessionId": "550e8400-e29b-41d4-a716-446655440000",
  "expiresAt": "2025-10-23T02:00:00Z",
  "contextType": "SCHEDULE"
}
```

**Usage:** Call this before uploading files. When editing an existing schedule, include `targetContextId` to verify write permission.

---

#### 2. Upload File
**Endpoint:** `POST /api/attachments`

**Request:** `multipart/form-data`
- `sessionId`: UUID (required)
- `file`: File (required)

**Response:**
```json
{
  "id": "660e8400-e29b-41d4-a716-446655440001",
  "contextType": "SCHEDULE",
  "contextId": null,
  "originalFilename": "meeting-notes.pdf",
  "contentType": "application/pdf",
  "size": 473829,
  "hasThumbnail": false,
  "thumbnailUrl": null,
  "orderIndex": 0,
  "createdAt": "2025-10-22T12:34:56+09:00",
  "createdBy": 42
}
```

**Errors:**
- `413 Payload Too Large`: File exceeds max size (50MB)
- `400 Bad Request`: Blacklisted extension (.exe, .bat, .cmd, .sh, .js)

---

#### 3. Finalize Session (Internal Use Only)
**Note:** Session finalization is handled internally by `ScheduleService` when saving schedules. There is no public API endpoint for this operation.

**Internal Flow:**
- When `ScheduleController.saveSchedule` receives `attachmentSessionId`, it passes it to `ScheduleService`
- `ScheduleService` creates/updates the schedule, then calls `AttachmentService.finalizeSessionForSchedule`
- Files move from temporary storage (`_tmp/{sessionId}/`) to permanent location (`SCHEDULE/{scheduleId}/`)
- Attachment entities are updated with `contextId` and `uploadSessionId` is cleared

---

#### 4. List Attachments
**Endpoint:** `GET /api/attachments?contextType=SCHEDULE&contextId=12345`

**Response:**
```json
[
  {
    "id": "660e8400-e29b-41d4-a716-446655440001",
    "contextType": "SCHEDULE",
    "contextId": "12345",
    "originalFilename": "photo.jpg",
    "contentType": "image/jpeg",
    "size": 245760,
    "hasThumbnail": true,
    "thumbnailUrl": "/api/attachments/660e8400-e29b-41d4-a716-446655440001/thumbnail",
    "orderIndex": 0,
    "createdAt": "2025-10-22T12:34:56+09:00",
    "createdBy": 42
  }
]
```

---

#### 5. Download File
**Endpoint:** `GET /api/attachments/{id}/download`

**Response:** Binary file stream with proper `Content-Disposition` header

**Usage:** Use this URL directly in `<a>` tags for download links.

---

#### 6. Get Thumbnail
**Endpoint:** `GET /api/attachments/{id}/thumbnail`

**Response:** PNG image (200x200 max, aspect ratio preserved)

**Usage:** Use this URL directly in `<img>` tags. Returns `404` if no thumbnail exists.

---

#### 7. Delete Attachment
**Endpoint:** `DELETE /api/attachments/{id}`

**Response:** `204 No Content`

**Usage:** Call this to remove individual attachments. Works for both temporary (session-based) and finalized attachments.

---

#### 8. Reorder Attachments
**Endpoint:** `POST /api/attachments/reorder`

**Request:**
```json
{
  "contextType": "SCHEDULE",
  "contextId": "12345",
  "orderedAttachmentIds": [
    "770e8400-e29b-41d4-a716-446655440002",
    "660e8400-e29b-41d4-a716-446655440001"
  ]
}
```

**Response:** `204 No Content`

**Usage:** Call this after drag-and-drop or manual reordering. Only works on finalized attachments.

---

### Context Types
- `SCHEDULE` - Schedule attachments (current implementation)
- `PROFILE` - User profile images (future)
- `TEAM` - Team cover images (future)
- `TODO` - Todo attachments (future)

### Configuration Values
- **Max file size:** 50 MB
- **Blacklisted extensions:** `.exe`, `.bat`, `.cmd`, `.sh`, `.js`
- **Thumbnail size:** 200x200px (max side, aspect ratio preserved)
- **Thumbnail format:** PNG only
- **Session expiry:** 24 hours

### Common Upload Flow

**Creating new schedule:**
1. `POST /api/attachments/sessions` → get `sessionId`
2. `POST /api/attachments` (repeat for each file) → collect attachment IDs
3. Save schedule form → get `scheduleId`
4. `POST /api/attachments/sessions/{sessionId}/finalize` with `scheduleId` and ordered IDs

**Editing existing schedule:**
1. `POST /api/attachments/sessions` with `targetContextId=scheduleId`
2. `POST /api/attachments` (repeat for new files)
3. `DELETE /api/attachments/{id}` (for removed files)
4. `POST /api/attachments/sessions/{sessionId}/finalize` with all attachment IDs (existing + new)

**Reordering after finalization:**
1. User drags attachments in UI
2. `POST /api/attachments/reorder` with new order

---

## Error Handling
- Blocked extensions return HTTP 400 with error code `ATTACHMENT_EXTENSION_BLOCKED`.
- Files exceeding `max-file-size` return HTTP 413 with code `ATTACHMENT_TOO_LARGE`.
- Requests referencing unknown attachments return HTTP 404.
- Permission failures (download/delete/finalize) return HTTP 403.
- Finalizing a session with a `contextId` that differs from the session's `targetContextId` returns HTTP 409 with code `ATTACHMENT_FINALIZE_MISMATCH`.

## Upload Workflow
1. Front-end requests a session before the schedule is saved. When editing an existing schedule, the session request includes `targetContextId` so the backend can verify write permission.
2. Files upload individually with the session ID. Server validates blacklist & size, writes to `_tmp`, creates `Attachment` with `uploadSessionId=sessionId` and `contextId=null`.
3. When the schedule is persisted or updated, the client submits the session ID along with the final `orderedAttachmentIds` (existing + new IDs). Backend binds new attachments to the schedule, moves files into the permanent directory, and updates `orderIndex` to match the provided order; any attachments omitted from the list keep their relative order but are appended after the listed ones.
4. Existing attachments are deleted by calling `DELETE /api/attachments/{id}` per file; they do not flow through ses sions.
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
- [x] Introduce `dutypark.storage` configuration properties with validation and unit tests for property binding/defaults.
- [x] Add Flyway migrations creating `attachment` and `attachment_upload_session` tables plus indexes; cover with migration smoke test using the existing in-memory database profile.
- [x] Define domain types (`Attachment`, `AttachmentUploadSession`, `AttachmentContextType`, DTO mappers) with Kotlin data/Entity classes and unit tests for mapping.
- [x] Implement `AttachmentRepository` and multi-context lookup query methods; cover with Spring Data JPA slice tests ensuring no N+1.
- [x] Build blacklist/size validation service that reads from configuration; write unit tests covering acceptance/rejection cases.
- [x] Implement storage path resolver & file system service handling write/delete/move with rollback on failure; cover via temporary filesystem tests.
- [x] Create image-only `ThumbnailService` (`ThumbnailGenerator` + implementation) with unit tests ensuring 200x200 constraint and graceful failure logging.
- [x] Develop `AttachmentUploadSessionService` and `AttachmentService` (create, finalize, reorder, delete) using TDD-focused service tests mocking storage/thumbnail components.
- [x] Wire permission checks through a dedicated evaluator; write unit tests ensuring context delegation and session ownership enforcement.
- [x] Expose REST controllers (`AttachmentSessionController`, `AttachmentController`) with MockMvc tests for upload, finalize, reorder, list, download, delete, thumbnail endpoints including error cases.
- [x] Integrate schedule deletion cascade through domain service/event listener; add integration test ensuring files removed from disk and DB.
- [x] Implement scheduled cleanup job with clock injection; write integration test asserting expired sessions/attachments removed.
    - Run the sweep daily at 02:00 server time using a scheduled service that reads `Instant.now(clock)`.
    - Remove expired upload sessions (`expiresAt < now`) by deleting their attachments via `AttachmentService.deleteAttachment` so both DB rows and files disappear, then prune the `_tmp` directory.
    - Integration test should create expired + active fixtures, execute the cleanup, and assert database state and filesystem directories/files reflect the deletions.
- [x] Update REST Docs snippets for all new endpoints; ensure asciidoctor build passes.

### Frontend (After Backend Completion)
- [x] **Attachment asset groundwork**
  - [x] Add Uppy CSS/JS includes (DragDrop, Dashboard, XHRUpload) to the shared layout so the widgets are usable inside the duty modal.
  - [x] Create `src/main/resources/static/icons/attachments/` with SVG thumbnails for pdf, doc, sheet, slide, zip, audio, video, and a generic fallback.
  - [x] Introduce attachment-specific CSS classes (using Bootstrap utilities where possible) to size previews, progress bars, and the file grid responsively.
  - [x] Centralize max-size/blocked-extension messages in `common.js` (or a new config module) for reuse across upload/validation flows.
  - **Briefing:** Layout loads the bundled Uppy assets from `static/lib/uppy-5.1.7/` (see `templates/layout/include.html:17`). Attachment styling lives in `static/css/attachments.css`, while SVG fallbacks are under `static/icons/attachments/`. Validation defaults are exposed via `window.AttachmentValidation` in `static/js/common.js`.
- [x] **Attachment session helpers**
  - [x] Add fetch-based helper functions (collocated with existing duty scripts) for createSession, upload, finalize, delete, list, and reorder calls.
  - [x] Implement a lightweight adapter that normalizes `AttachmentDto` into `{ id, name, size, contentType, thumbnailUrl, downloadUrl, isImage }`.
  - [x] Surface SweetAlert-based error handling for size/blacklist responses so the UI can present immediate feedback.
  - [x] Ensure the helpers expose promise-based hooks for progress updates so Uppy can reflect server responses.
  - **Briefing:** Attachment lifecycle helpers are defined inside `static/js/duty/detail-view-modal.js` (top of file). Reuse `normalizeAttachmentDto`, `createAttachmentSession`, `uploadAttachment`, etc., and tap into validation via `validateAttachment`. Progress callbacks use the `buildUploadProgressPayload` payload shape.
- [x] **Schedule create modal uploader**
  - [x] Instantiate an Uppy instance when `scheduleCreateMode` starts, wiring Drag&Drop + file input button inside the modal after the visibility controls.
  - [x] Render a list of pending/completed files with image previews (using `URL.createObjectURL`) or SVG icons before the backend thumbnail exists.
  - [x] Show per-file progress bars while uploads are in-flight and allow cancel/removal before save.
  - [x] Prevent duplicate uploads by checking Uppy state against already attached file names and size limits.
- [x] **Save/finalize pipeline**
  - [x] Request an upload session on modal entry (reusing existing session when editing) and tear it down on cancel.
  - [x] Update `saveSchedule` to send `orderedAttachmentIds` along with schedule data, then call `POST /api/attachments/sessions/{id}/finalize`.
  - [x] Handle optimistic UI while schedule persists (disable buttons, show waitMe overlay) and roll back Uppy state on failure.
  - [x] Append any post-save attachments from the finalize response into local state so the calendar refresh matches backend order.
- [ ] **Editing existing schedules**
  - [ ] Hydrate existing attachments into the uploader when `scheduleEditMode` toggles, preserving order and ownership metadata.
  - [ ] Allow users to delete finalized attachments (`DELETE /api/attachments/{id}`) and immediately reflect removals in both UI and local state.
  - [ ] Support adding new files to the same Uppy queue during edit sessions and track combined ordering.
  - [ ] Reconcile reordered attachments by calling `/api/attachments/reorder` when users drag to rearrange finalized items.
- [ ] **Calendar attachment indicators**
  - [ ] Extend `loadSchedule` response handling so each schedule in `schedulesByDays` includes an `attachments` array.
  - [ ] Show a paperclip icon (e.g., `bi bi-paperclip`) next to the description icon when attachments exist; clicking should open the enriched detail view.
  - [ ] Update `showDescription(schedule)` to render both description text and attachment thumbnails/download links in the SweetAlert dialog.
  - [ ] Ensure accessibility text (sr-only labels) communicates attachment counts for screen readers.
- [ ] **Detail modal attachment panel**
  - [ ] Insert an attachment gallery section in `detail-view-modal.html` after the description block, using Bootstrap grid utilities for layout.
  - [ ] Display image thumbnails (`thumbnailUrl`) or SVG icons with filename, size, and a download button linking to `/api/attachments/{id}/download`.
  - [ ] Provide remove buttons (X) for each attachment when in create/edit mode that sync with the Uppy/attachment store.
  - [ ] Add responsive tweaks so thumbnails wrap cleanly on mobile (e.g., `row-cols-3 row-cols-sm-4`), matching the project's mobile-first styling.

## Known Issues & Future Work

### Thumbnail Generation Timing Issue (RESOLVED)
- **Problem:** Thumbnails were not being generated during attachment upload due to transaction timing issues.
- **Root Cause:**
  - `AttachmentService.uploadFile` saved the attachment entity
  - Immediately called `thumbnailService.generateThumbnailAsync` with `REQUIRES_NEW` propagation
  - New transaction couldn't see uncommitted attachment entity from parent transaction
- **Solution Implemented:**
  - Introduced `AttachmentUploadedEvent` domain event
  - `AttachmentService` publishes event after saving attachment
  - `ThumbnailService` handles event with `@TransactionalEventListener(phase = AFTER_COMMIT)`
  - Removed `REQUIRES_NEW` propagation, using standard `@Transactional`
  - Thumbnail generation now starts asynchronously after parent transaction commits
- **Benefits:**
  - Clean separation of concerns (event-driven architecture)
  - Guaranteed entity visibility when thumbnail generation starts
  - Thumbnail failures don't affect attachment upload transaction
  - Easy to extend for other post-upload processing in the future
