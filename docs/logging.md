# Server logging

Server logs serve two purposes: audit successful user actions and diagnose operational failures. Keep those records distinct so a failure message does not look like a completed action.

This audit reviewed 120 Kotlin backend logger call sites. It focused on existing records that named an operation but left out the actor, affected resource, changed values, or useful failure location.

| Domain | Audit outcome |
| --- | --- |
| Team and duty management | Mutation records now identify the actor and target and include before/after values for actual changes. Success records wait for transaction commit. |
| Authentication, tokens, admin, and OAuth | Records include available actor or flow/provider context and safe status/error codes. Free-form provider descriptions and credential values are excluded. |
| Attachments, profiles, D-Day, todos, consent, access, inquiries, and holidays | Records carry the relevant member/resource identifiers and operation outcome so the event can be traced without logging entity dumps. |
| Notifications, push, and account deletion | Async records carry event, recipient, or job identifiers and useful cause types and stack frames without exception messages. |
| AI schedule parsing | Results include schedule ID, parsing generation, and owner ID. Meaningful before/after text and model output remain available as escaped single-line JSON. |
| Existing adequate diagnostics | Configuration and cleanup counts, Holiday API duration/status, global request exception diagnostics, and Slack classification logs already provide useful context and remain unchanged. Slack privacy tests continue to protect that path. |

## User actions

Use `Logger.auditEventAfterCommit` for completed actions and `Logger.auditChangeAfterCommit` for updates. Include the actor's ID and display name, target IDs and useful names, and the values that changed. If the actor is unknown, record it as `null`. For impersonation, include the effective actor ID/name and original actor ID when available. Derive audit context from values already needed or loaded by the business operation; never add database queries, transaction boundaries, external calls, filesystem metadata probes, eager/lazy relation traversal, or repeated collection traversal solely to enrich logs. Use IDs when names are unavailable. Change records omit unchanged and sensitive fields. When a transaction is active, success records are written only after commit.

Do not use email to identify an actor. Do not log passwords, tokens, provider credentials, authorization headers, or other authentication secrets. Use `auditContext(fields)` for immediate warning and error context; it produces a single-line JSON object and filters exact sensitive field names. Pass scalar values and explicit IDs rather than entities.

## Operational diagnostics

Include the operation, relevant resource or task IDs, outcome, and exception type or cause type. Include provider status or allowlisted error codes when available. Avoid exception messages and stack traces when they can echo request or credential data.

Some existing diagnostics intentionally include user-entered schedule text and the AI parser's response. Preserve those values when they are needed to investigate parsing, but serialize the context through `auditContext` so embedded newlines and control characters cannot create extra log records. Keep those diagnostics correlated with the schedule ID, parsing generation, and owner ID.

Cleanup counts, API duration and status, and the global request exception record already provide useful operational context. `ErrorDetectAdvisor` records the route pattern, exception types, and message-free stack frames. Keep those focused records rather than adding request bodies or generic entity dumps.
