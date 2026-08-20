# Dutypark Agent Instructions

The source code, tests, and task-specific documentation are the source of truth for implementation details.

## Implementation

- Read the relevant code, tests, and local instructions before editing.
- Before implementation, ask clarifying questions about any remaining material ambiguity that affects scope, behavior, interfaces, or acceptance criteria. Do not proceed on material assumptions.
- For behavior changes and bug fixes, start with a focused failing test whenever practical.
- Follow RED–GREEN–REFACTOR: confirm the test fails for the intended reason, make the smallest change that passes it, then refactor while keeping tests green.
- Make the smallest, simplest change that fully satisfies the request.
- Do not invent requirements, broaden scope, or add speculative abstractions or dependencies.
- Follow existing conventions and preserve unrelated behavior and work.
- Write clear code. Comment only non-obvious rationale, invariants, or constraints.

### Dutypark Scope

- Do not start development servers (`./gradlew bootRun`, `npm run dev`) unless the user explicitly asks.
- The user usually keeps the dev servers running already: the web on `http://localhost:5173` and the backend on `http://localhost:8080`. Check those ports before concluding a server is unavailable, and use the running ones for verification instead of starting your own.
- Unless explicitly platform-specific, complete service features and user-facing policy, UI, or UX changes across the backend, responsive web, and native iOS. If a client is deferred, report the gap and do not mark the work complete.

### Local Development

- The local development database is defined in `dutypark_dev_db/docker-compose.yml`. Start it with `(cd dutypark_dev_db && docker compose up -d)`.
- Local backend database connection settings are in `src/main/resources/application-dev.yml`.
- Check for already-running servers with `lsof -nP -iTCP:5173 -iTCP:8080 -sTCP:LISTEN`. If a port is listening, that server is the user's: use it, and never restart or stop it.

### Flyway Migrations

- Once a versioned Flyway migration file is created, treat it as immutable: never modify its contents, rename it, renumber it, or delete it.
- Add every follow-up change or correction as a new migration with a version higher than all existing migrations.

## Delegation and Parallel Work

- The main agent's primary role is orchestration: planning, decomposition, delegation, coordination, review, user communication, and handling additional work—not hands-on execution.
- Delegate repository exploration, implementation, testing, and verification to subagents by default. Do not occupy the main agent with substantial work that can be delegated.
- Maximize safe parallelism across independent workstreams.
- The main agent may directly handle only brief, local tasks that do not benefit from delegation, as well as integration, conflict resolution, or work that requires its broader context.
- Give each delegated task a single owner with explicit scope, deliverables, dependencies, and verification criteria.
- Parallelize only independent work. Concurrent writes must not overlap in files, mutable state, or contracts.
- Shared files and cross-cutting contracts must have a single owner.
- The main agent remains accountable for integration, review of the final diff and verification results, and the accuracy of the completion report.

## Completion

- Run verification proportional to the change, starting with focused checks and expanding based on risk and blast radius.
- Never weaken or bypass tests or checks to make a change pass.
- Do not claim completion without relevant verification. State exactly what was not verified and why.
- Distinguish failures caused by the current change from pre-existing failures.
- Report what changed, the checks run and their results, unverified areas, and remaining risks or assumptions.

### Dutypark Verification

- Backend: run focused Gradle tests first, then expand by risk.
- Web: run `npm run type-check` and `npm run build`, plus affected tests.
- iOS: when affected, run the build and `DutyparkTests` unit tests documented in `ios/README.md` by default.
- Do not run `DutyparkUITests` as part of default verification, including UI tests related to the changed area. Run specific or full iOS UI tests only when the user explicitly requests them; full iOS UI test runs are strictly opt-in.
- After completing an iOS app change, install the latest successfully verified build on the simulator named exactly `iPhone 13 mini` so the user can inspect it immediately. This does not authorize starting a development server. If that simulator is unavailable or installation is blocked by CoreSimulator or another error, report the exact reason.

## Git

- Write all GitHub-facing communication and metadata in English, including issue and PR titles and bodies, comments, and review comments. This does not require localized user-facing product content or app release note copy to be in English.
- Do not perform version-control operations that change local or remote repository state unless explicitly requested.
- Before any requested version-control write, inspect the working tree and relevant diffs.
- Commit only changes made for the current task.
- Treat pre-existing changes as user-owned. Never discard, overwrite, stage, or commit unrelated work.

### Release Notes

- Every human-authored PR to `main` requires exactly one release note. Follow `frontend/src/releaseNotes/README.md`, obtain the real PR number before adding its entry, and never guess the PR number.

## Communication

- Respond to the user in Korean.
