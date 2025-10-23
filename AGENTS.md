This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Dutypark is a Spring Boot web application built with Kotlin for duty and schedule management. It features a Vue.js
frontend with Thymeleaf templates, MySQL database, and Docker-based deployment with monitoring stack.

**Tech Stack:**

- Backend: Kotlin + Spring Boot 3.4.3, Spring Data JPA, Spring Security
- Frontend: Thymeleaf templates, Vue.js, Bootstrap
- Database: MySQL 8.0 with Flyway migrations
- Build: Gradle with Kotlin DSL
- Deployment: Docker + Docker Compose + Nginx
- Monitoring: Prometheus + Grafana
- AI: Spring AI with Gemini integration
- Authentication: JWT + OAuth (Kakao)

## Development Commands

### Build and Run

```bash
# Build the application
./gradlew build

# Run application locally
./gradlew bootRun

# Run tests
./gradlew test

# Clean build
./gradlew clean build

# Generate Spring REST Docs
./gradlew asciidoctor
```

**Build Guidelines:**

- **Frontend-only changes** (JS/HTML/CSS files in `src/main/resources/static/` or `templates/`): No gradle build
  required. Changes are served directly by Spring Boot DevTools or after application restart.
- **Backend changes** (Kotlin/Java code, dependencies, configuration): Run `./gradlew build` to compile and package.
- **Testing**: Use `./gradlew test` for backend tests. Frontend changes can be verified directly in the browser.

### Docker Development

```bash
# Run full stack with Docker Compose
docker compose up -d

# Local development (HTTP only)
NGINX_CONF_NAME=nginx.local.conf docker compose up -d

# Run only database for local development
cd dutypark_dev_db && docker compose up -d
```

### Environment Setup

```bash
# Copy environment template
cp .env.sample .env
# Edit .env with your configuration
```

## Architecture Overview

### Package Structure

```
com.tistory.shanepark.dutypark/
├── admin/          - Admin functionality (user management, teams)
├── attachment/     - File upload, thumbnail generation, storage management
├── common/         - Shared utilities, config, exceptions, external APIs
├── dashboard/      - Main dashboard views
├── duty/           - Core duty management (schedules, batch imports, duty types)
├── holiday/        - Holiday integration with data.go.kr API
├── member/         - User management, friends, D-Day counters, SSO
├── schedule/       - Event scheduling with LLM-based parsing
├── security/       - Authentication, JWT, OAuth (Kakao)
├── team/           - Team/organization management with roles
└── todo/           - Todo list functionality with completion tracking
```

### Entity Structure & Relationships

#### Base Classes

- **EntityBase**: UUID (ULID) primary key, audit fields (`createdDate`, `lastModifiedDate`)
    - Used by: `Attachment`, `Schedule`, `Todo`, `TeamManager`
- **BaseTimeEntity**: Long ID with audit fields only
    - Used by: `Team`, `Member`, `ScheduleTag`

#### Core Entities & Relationships

**Member** (`member/domain/entity/Member.kt`)

- Long ID (IDENTITY)
- Fields: `name`, `email`, `password`, `kakaoId`, `calendarVisibility`
- Relationships: `@ManyToOne Team`, has many `Duty`, `Schedule`, `Todo`

**Team** (`team/domain/entity/Team.kt`)

- Long ID (IDENTITY), extends `BaseTimeEntity`
- Fields: `name` (unique), `description`, `defaultDutyColor`, `defaultDutyName`, `workType`, `dutyBatchTemplate`
- Relationships:
    - `@ManyToOne admin` (Member)
    - `@OneToMany managers` (TeamManager, cascade ALL)
    - `@OneToMany members` (Member)
    - `@OneToMany dutyTypes` (DutyType, cascade ALL, ordered by position)
- Key methods: `addMember()`, `removeMember()`, `addDutyType()`, `changeAdmin()`, `isManager()`, `isAdmin()`

**Duty** (`duty/domain/entity/Duty.kt`)

- Long ID (IDENTITY)
- Fields: `dutyDate` (LocalDate)
- Relationships: `@ManyToOne dutyType` (nullable), `@ManyToOne member` (not-null)

**DutyType** (`duty/domain/entity/DutyType.kt`)

- Long ID (IDENTITY)
- Fields: `name`, `position`, `color` (hex string, 7 chars)
- Relationships: `@ManyToOne team`, `@OneToMany duties` (cascade ALL)

**Schedule** (`schedule/domain/entity/Schedule.kt`)

- UUID ID via `EntityBase`
- Fields: `content` (50 chars), `description` (4096 chars), `startDateTime`, `endDateTime`, `position`, `visibility` (
  enum), `parsingTimeStatus` (enum), `contentWithoutTime`
- Relationships: `@ManyToOne member`, `@OneToMany tags` (ScheduleTag, cascade ALL)
- Methods: `addTag()`, `removeTag()`, `hasTimeInfo()`

**Todo** (`todo/domain/entity/Todo.kt`)

- UUID ID via `EntityBase`
- Fields: `title` (50 chars), `content` (50 chars), `position`, `status` (ACTIVE/COMPLETED), `completedDate`
- Relationships: `@ManyToOne member`
- Methods: `update()`, `markCompleted()`, `markActive()`

**Attachment** (`attachment/domain/entity/Attachment.kt`)

- UUID ID via `EntityBase`
- Fields: `contextType` (enum), `contextId`, `uploadSessionId`, `originalFilename`, `storedFilename`, `contentType`,
  `size`, `storagePath`, `thumbnailFilename`, `thumbnailContentType`, `thumbnailSize`, `thumbnailStatus` (enum),
  `orderIndex`, `createdBy`
- Indexed by: contextType+contextId, uploadSessionId

### Key Design Patterns

#### Controllers

**REST Controllers** (`*Controller.kt`)

```kotlin
@RestController
@RequestMapping("/api/duty")
class DutyController(private val dutyService: DutyService) {
    @GetMapping
    fun getDuties(@Login loginMember: LoginMember, ...): List<DutyDto>
}
```

**View Controllers** (`*ViewController.kt`)

```kotlin
@Controller
class DutyViewController : ViewController() {
    @GetMapping("/duty/{id}")
    fun retrieveMemberDuty(@Login(required = false) loginMember: LoginMember?, model: Model, ...): String {
        return layout(model, "duty/duty")  // Returns template path
    }
}
```

- All view controllers extend `ViewController` base class
- Use `layout(model, templateName)` helper method

#### Services

```kotlin
@Service
@Transactional
class DutyService(
    private val dutyRepository: DutyRepository,
    private val dutyTypeRepository: DutyTypeRepository,
) {
    private val log = logger()  // Extension function from LogbackConfig

    fun updateDuty(...) { /* business logic */
    }
}
```

- Always annotated with `@Service` and `@Transactional`
- Constructor injection for dependencies
- Use `logger()` extension function for logging

#### Repositories

```kotlin
interface DutyRepository : JpaRepository<Duty, Long> {
    @EntityGraph(attributePaths = ["dutyType"])
    fun findAllByMemberAndDutyDateBetween(member: Member, start: LocalDate, end: LocalDate): List<Duty>

    fun findByMemberAndDutyDate(member: Member, dutyDate: LocalDate): Duty?

    @Modifying
    fun deleteDutiesByMemberAndDutyDateBetween(member: Member, start: LocalDate, end: LocalDate)
}
```

- Extend `JpaRepository<Entity, ID>`
- Use `@EntityGraph` for eager loading associations (prevent N+1)
- Use `@Query` for complex queries, `@Modifying` for UPDATE/DELETE

### Common Utilities & Annotations

#### Authentication

**@Login Annotation** (`member/domain/annotation/Login.kt`)

```kotlin
@Login(required = true)   // Default, throws exception if not logged in
@Login(required = false)  // Returns null if not logged in
```

- Injects `LoginMember` DTO into controller parameters
- `LoginMember`: Contains `id`, `email`, `name`, `team`, `isAdmin`

#### Exception Handling

- **DutyparkException**: Base class for all custom exceptions with `errorCode: Int`
- **AuthException**: For 401 authentication errors
- **RestExceptionControllerAdvice**: Handles REST API exceptions
- **ViewExceptionControllerAdvice**: Handles view controller exceptions

#### Key Enumerations

- **Visibility** (member/domain/enums/): `PUBLIC`, `FRIENDS`, `FAMILY`, `PRIVATE`
    - Methods: `publicOnly()`, `friends()`, `family()`, `all()`
- **WorkType** (team/domain/enums/): `WEEKDAY`, `WEEKEND`, `FIXED`, `FLEXIBLE`
- **ParsingTimeStatus** (schedule/domain/enums/): `WAIT`, `SKIP`, `PARSED`, `NO_TIME_INFO`, `ALREADY_HAVE_TIME_INFO`,
  `FAILED`
- **TodoStatus** (todo/domain/entity/): `ACTIVE`, `COMPLETED`
- **AttachmentContextType** (attachment/domain/enums/): Context where attachments are used
- **ThumbnailStatus** (attachment/domain/enums/): `NONE`, `PENDING`, `SUCCESS`, `FAILED`, etc.

### Quick Navigation Guide

| Task                        | Primary File Location                                                                        | Related Files                                                                        |
|-----------------------------|----------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------|
| **Add new duty feature**    | `duty/service/DutyService.kt`<br>`duty/controller/DutyController.kt`                         | `duty/domain/entity/Duty.kt`<br>`duty/repository/DutyRepository.kt`                  |
| **Modify calendar view**    | `templates/duty/duty.html`<br>`static/js/duty/duty.js`                                       | `duty/controller/DutyViewController.kt`                                              |
| **Add schedule feature**    | `schedule/service/ScheduleService.kt`<br>`schedule/controller/ScheduleController.kt`         | `schedule/domain/entity/Schedule.kt`                                                 |
| **AI time parsing**         | `schedule/timeparsing/service/ScheduleTimeParsingService.kt`                                 | `schedule/domain/enums/ParsingTimeStatus.kt`                                         |
| **File upload/attachments** | `attachment/service/AttachmentService.kt`<br>`attachment/controller/AttachmentController.kt` | `attachment/domain/entity/Attachment.kt`<br>`attachment/service/ThumbnailService.kt` |
| **Todo functionality**      | `todo/service/TodoService.kt`<br>`todo/controller/TodoController.kt`                         | `todo/domain/entity/Todo.kt`                                                         |
| **Team management**         | `team/service/TeamService.kt`<br>`team/controller/TeamController.kt`                         | `team/domain/entity/Team.kt`<br>`team/domain/entity/TeamManager.kt`                  |
| **Authentication/Login**    | `security/service/AuthService.kt`<br>`security/filters/JwtAuthFilter.kt`                     | `security/config/SecurityConfig.kt`<br>`security/oauth/kakao/`                       |
| **Member/Friends**          | `member/service/MemberService.kt`<br>`member/service/FriendService.kt`                       | `member/domain/entity/Member.kt`<br>`member/domain/entity/FriendRelation.kt`         |
| **Add REST endpoint**       | `*/controller/*Controller.kt`                                                                | Create DTO in `*/domain/dto/`                                                        |
| **Add new page**            | `*/controller/*ViewController.kt`<br>`templates/{domain}/{page}.html`                        | `static/js/{domain}/{page}.js`                                                       |
| **Database migration**      | `src/main/resources/db/migration/v2/`                                                        | Follow `V{version}__{description}.sql`                                               |
| **Exception handling**      | `common/exceptions/`                                                                         | `common/advice/RestExceptionControllerAdvice.kt`                                     |
| **Shared utilities**        | `common/utils/`                                                                              | `common/config/`                                                                     |

### Frontend File Structure

```
templates/
├── layout/
│   ├── layout.html      - Main wrapper (includes header, content, footer)
│   ├── include.html     - CSS/JS imports
│   └── footer.html
├── duty/
│   ├── duty.html        - Main calendar view
│   ├── day-grid.html    - Calendar grid component
│   └── modals/          - Duty-related modals
├── schedule/            - Schedule views
├── member/              - Login, profile, SSO pages
├── team/                - Team management pages
├── admin/               - Admin pages
└── error/

static/
├── css/                 - Custom stylesheets
├── js/
│   ├── common.js        - Shared utilities
│   └── duty/            - Duty page modules
│       ├── duty.js      - Main logic
│       ├── todo-list-methods.js
│       ├── day-grid.js
│       └── ...
└── lib/                 - External libraries (Bootstrap, dayjs, pickr, uppy, etc.)
```

### Critical Architecture Notes

1. **Multi-tenancy**: All users belong to Teams; Team-based organization
2. **Lazy Loading**: Most relationships use `FetchType.LAZY` to avoid N+1 queries
3. **Cascade Operations**: Parent entities (Team, Schedule) cascade deletes to children
4. **UUID vs Long IDs**:
    - UUID (EntityBase): Attachment, Schedule, Todo, TeamManager
    - Long (IDENTITY): Member, Team, Duty, DutyType, Holiday
5. **JWT Tokens**: Stored in cookies, validated by `JwtAuthFilter`
6. **Permission Model**: Visibility enums + friend relationships + admin roles
7. **Mobile-first UI**: Bootstrap utility classes over inline styles

## Development Guidelines

### Database Changes

- All schema changes must be done via Flyway migrations
- Migration files in `src/main/resources/db/migration/v2/`
- Follow naming convention: `V{version}__{description}.sql`

### Authentication Testing

- Test users can be created via admin interface
- JWT tokens are required for authenticated endpoints
- Use `@Login` annotation for controller method authentication

### External API Integration

- Data.go.kr API for Korean public holidays
- Kakao OAuth for user authentication
- All API keys configured via environment variables

### Frontend Integration

- Thymeleaf templates in `src/main/resources/templates/`
- Vue.js components embedded in templates
- Bootstrap for responsive design
- **Mobile-first approach**: This project prioritizes mobile usability over desktop experience

### CSS and Styling Guidelines

- **Always prefer Bootstrap utility classes over inline styles**
- Use Bootstrap spacing classes: `m-*`, `p-*`, `mt-*`, `mb-*`, `mx-*`, `my-*`, etc.
- Use Bootstrap display classes: `d-flex`, `d-block`, `d-none`, etc.
- Use Bootstrap positioning: `justify-content-*`, `align-items-*`, `text-center`, etc.
- Use Bootstrap sizing: `w-*`, `h-*`, `gap-*`, etc.
- Only use inline styles for dynamic values (colors, measurements from variables)
- Examples:
    - ❌ `style="margin-top: 10px; display: flex;"`
    - ✅ `class="mt-2 d-flex"`
    - ❌ `style="padding: 8px 16px; border: 1px solid #eee;"`
    - ✅ `class="px-3 py-2 border"`

### Code Comments Policy

- **Minimize comments - prefer self-documenting code**
- Only add comments when:
    - The code logic is genuinely complex and cannot be simplified
    - Preventing bugs or explaining non-obvious behavior
    - Documenting workarounds for external library issues
    - Explaining "why" when the reason is not obvious from the code itself
- Do NOT add comments that:
    - Simply restate what the code does
    - Explain obvious variable names or simple logic
    - Add noise without providing value
- Examples:
    - ❌ `// Check if the selected type is already the current duty type`
    - ✅ No comment needed - use clear variable names like `isAlreadySelected`
    - ✅ `// Workaround: Vue reactivity doesn't track closure dependencies properly`

## Testing

### Test Structure

- Unit tests: Service layer testing with mocking
- Integration tests: Full application context testing
- Controller tests: MockMvc-based API testing
- Spring REST Docs: API documentation generation
- Prefer @Transactional for automatic DB rollback

### Testing Best Practices

#### What to Test

- **Security**: Unauthorized access, wrong user ownership, input sanitization
- **Edge cases**: Empty lists, null values, special characters, boundary conditions
- **Performance**: N+1 queries, transaction boundaries, resource cleanup
- **Errors**: Missing resources, permission failures, file system issues

### Running Specific Tests

```bash
# Run single test class
./gradlew test --tests "ClassName"

# Run tests with pattern
./gradlew test --tests "*ServiceTest"

# Run with clean build
./gradlew clean test --tests "*ControllerTest"

# Test with coverage
./gradlew test jacocoTestReport
```

## Collaboration Preferences

- Always confirm requirements with short, numbered questions when clarification is needed; the user prefers replying by
  number.
- Follow a TDD workflow and tackle work in small, sequential steps—complete backend tasks before moving on to frontend
  pieces for cross-cutting features.
- When introducing configurable behaviors (file storage paths, limits, blacklists), surface them through
  `application.yml` properties with sensible defaults.
- Prefer writing plans and specs in `issue-*.md` files before coding; keep them updated as decisions evolve.

### Task Execution Guidelines

- **Work on ONE checklist item at a time** - never attempt multiple checklist items simultaneously.
- Break each checklist item into smaller, manageable todos (typically 3-5 todos per checklist item).
- Keep individual todos small to prevent work from going off track.
- Complete all todos for the current checklist item before moving to the next.
- **After completing all todos for a checklist item, STOP and present the code for user review.**
- **NEVER commit automatically** - wait for explicit user instruction like "commit this".
- Only move to the next checklist item after user confirms the current work and explicitly requests commit.

## Configuration

### Environment Variables (see .env.sample)

- Database: MySQL connection settings
- JWT: Secret key for token signing
- OAuth: Kakao REST API key
- External APIs: Data.go.kr service key, Gemini API key
- SSL: Domain and certificate configuration

### Profiles

- dev profile for local development

### Docker Deployment

- Multi-service setup: app, database, nginx, prometheus, grafana
- SSL certificate integration with Let's Encrypt
- Health checks and restart policies configured

## Git Commit Policy & Convention

**NEVER commit changes automatically or proactively.**

- Only commit when the user explicitly asks for a commit with clear instructions like "커밋해줘", "commit this", "create a
  commit", etc.
- Do not commit after completing tasks, even if the work is finished
- Do not suggest committing unless specifically asked
- Let the user decide when and what to commit
- **When creating commit messages, analyze only the actual code changes since the last commit, not the conversation
  history.** The commit message should reflect the final code state and changes, not the iterative development process
  discussed in chat.
- This rule is ABSOLUTE and must NEVER be violated
- **Format:** `type: summary`
    - `type` must be lowercase and chosen from the observed set `{feat, fix, chore, refactor}`. Use `chore` (not
      `chores`) for maintenance work. Prefer `docs`, `test`, `build`, or `ci` when more specific categories apply.
    - `summary` is a concise, imperative English description (e.g., `fix: ensure duty modal opens on mobile`). Avoid
      sentence casing, trailing periods, or mixed languages.
- **Body:** add a blank line after the summary if more context is required. Wrap at ~72 chars per line. Mention issue
  IDs only when relevant.
- **Verification:** always run `git log --oneline -10` before committing to confirm the new message aligns with recent
  history. Reword (`git commit --amend`) if it deviates.
