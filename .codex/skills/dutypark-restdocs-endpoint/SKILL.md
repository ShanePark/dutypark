---
name: dutypark-restdocs-endpoint
description: Create or update Dutypark backend API endpoints with matching REST Docs coverage. Use when changing Spring controller contracts, request or response payloads, path or query parameters, snippet generation, or AsciiDoc API documentation in this repository.
---

# Dutypark REST Docs Endpoint

Assume the current working directory is the Dutypark repository root.

## Workflow

1. Find the controller and the nearest existing `*ControllerTest.kt` first. Match the surrounding conventions before adding anything new.
2. Use `RestDocsTest` for documented controller tests. Reuse existing snippet naming patterns from nearby tests instead of inventing a new structure.
3. Cover the behavior change in tests before updating snippets. Include auth, ownership, or permission assertions when the endpoint depends on them.
4. Document every public request part that changed: path params, query params, headers, request fields, response fields, and pagination fields when present.
5. Use `subsectionWithPath()` for optional nested arrays or objects that are easier to describe as a block.
6. Update `src/docs/asciidoc/index.adoc` when a new resource or section is introduced.
7. Verify with the narrowest useful test first, then run `./gradlew asciidoctor`.

## Dutypark-Specific Notes

- Public API controllers live under `src/main/kotlin/com/tistory/shanepark/dutypark/**/controller`.
- REST Docs base classes live in `src/test/kotlin/com/tistory/shanepark/dutypark/RestDocsTest.kt` and `src/test/kotlin/com/tistory/shanepark/dutypark/DutyparkIntegrationTest.kt`.
- Good reference tests include:
  - `src/test/kotlin/com/tistory/shanepark/dutypark/member/controller/FriendControllerTest.kt`
  - `src/test/kotlin/com/tistory/shanepark/dutypark/team/controller/TeamControllerTest.kt`
  - `src/test/kotlin/com/tistory/shanepark/dutypark/policy/controller/PolicyControllerTest.kt`
- `./gradlew build` already depends on `asciidoctor`, but use `./gradlew asciidoctor` for focused verification while iterating.

## Guardrails

- Do not leave controller contract changes undocumented.
- Do not update snippets without updating the test that produces them.
- If the endpoint is intentionally undocumented, state that explicitly in the final response instead of silently skipping docs.
