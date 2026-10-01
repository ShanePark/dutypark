# Server logging

Server logs serve two purposes: audit successful user actions and diagnose operational failures. Keep those records distinct so a failure message does not look like a completed action.

The earlier audit improved 120 existing Kotlin logger call sites. The follow-up audit also inspected backend controllers, mutation services, external integrations, and workers for operations that had no log at all. The inventory below records the resulting coverage and intentional exclusions.

| Domain | Coverage |
| --- | --- |
| HTTP requests and handled errors | Generated request ID, HTTP method, matched route, response status, duration, available actor, normalized error code, and exception type. Mutation outcomes use INFO; errors use WARN except ordinary 404s at DEBUG. Successful reads stay quiet. |
| Signup, authentication, OAuth, and sessions | Signup records the saved member and provider; successful login, token issuance, provider linking/unlinking, reauthentication, and OAuth flow transitions carry safe actor, session, flow, or provider identifiers. Credentials and raw OAuth state/codes are excluded. |
| Member settings, consent, D-Day, friends, managers, and blocks | Creation, changes, and removals include actors, target identifiers, and changed scalar fields; repeated no-op actions do not produce completed-change records. |
| Account deletion and administration | Submission, completion/retry workflows, suspension, reinstatement, and administrative decisions identify the actor, affected account/job, and outcome. |
| Team, duty, schedules, todos, and imports | Previously missing creations and removals join existing update records. IDs, affected dates/counts, relationship changes, and actors distinguish individual and batch operations. |
| Reports and inquiries | Submission, cancellation, status changes, answers, memo changes, and moderation deletions identify the record and actor. Private submissions, snapshots, answers, and memos are represented by presence/length or safe classifications rather than raw content. |
| Attachments and profiles | Existing detailed upload/delete/thumbnail diagnostics remain; upload-session creation now identifies ownership, context, and expiry. |
| Notifications and push | Notification creation/removal, subscription registration/reassignment/removal, and APNs installation changes complement existing detailed delivery-failure diagnostics. Reading notifications stays quiet. |
| Holidays and cleanup | Holiday fetches record year, duration, count, and safe failures. Database mutation summaries wait for commit. Existing useful cleanup counts and diagnostics remain; empty cleanup runs stay quiet. |
| Slack | Original business failures propagate to the global handler without being mislabeled as Slack failures. Submission and delivery failures are distinguished, with safe exception classification and captured request correlation. |
| AI schedule parsing | Existing generation, schedule/owner identifiers, and escaped parsing diagnostics remain. |
| Read-only resources and configuration | Public content, search, dashboard/read endpoints, and ordinary cache hits do not need additional INFO events. Existing startup/configuration diagnostics remain. No backend backup service was found. |

## Request correlation

`RequestLoggingFilter` generates a UUID for each request, exposes it in `X-Request-ID`, and places it in MDC while the request executes. Incoming request IDs are not trusted. `auditContext` includes the current request ID in JSON; after-commit helpers serialize it when the event is registered so later MDC changes cannot move an event to another request. Slack asynchronous diagnostics capture the originating ID explicitly. MDC is restored in `finally`.

Request logs use Spring's matched route pattern, never the raw URI or query string. If no route is available, the pattern is `<unmatched>`. Handled REST failures expose only normalized application error codes and exception class names to the request logger. They do not alter the error response contract. Global unexpected-error diagnostics retain message-free stack frames and include request correlation.

## User actions

Use `Logger.auditEventAfterCommit` for completed actions and `Logger.auditChangeAfterCommit` for updates. Include the actor's ID and display name, target IDs and useful names, and the values that changed. If the actor is unknown, record it as `null`. For impersonation, include the effective actor ID/name and original actor ID when available. Derive audit context from values already needed or loaded by the business operation; never add database queries, transaction boundaries, external calls, filesystem metadata probes, eager/lazy relation traversal, or repeated collection traversal solely to enrich logs. Use IDs when names are unavailable. Change records omit unchanged and sensitive fields. When a transaction is active, success records are written only after commit.

Do not use email to identify an actor. Do not log passwords, tokens, provider credentials, authorization headers, proof/receipt credentials, social account identifiers, raw OAuth state/authorization codes, or other authentication secrets. Use `auditContext(fields)` for immediate warning and error context; it produces a single-line JSON object and filters exact sensitive field names. Pass scalar values and explicit IDs rather than entities.

## Operational diagnostics

Include the operation, relevant resource or task IDs, outcome, and exception type or cause type. Include provider status or allowlisted error codes when available. Avoid exception messages and stack traces when they can echo request or credential data.

Some existing diagnostics intentionally include user-entered schedule text and the AI parser's response. Preserve those values when they are needed to investigate parsing, but serialize the context through `auditContext` so embedded newlines and control characters cannot create extra log records. Keep those diagnostics correlated with the schedule ID, parsing generation, and owner ID.

Preserve useful cleanup counts, API duration/status, and global request exception diagnostics. `ErrorDetectAdvisor` records the route pattern, exception types, and message-free stack frames. Keep those focused records rather than adding request bodies or generic entity dumps.
