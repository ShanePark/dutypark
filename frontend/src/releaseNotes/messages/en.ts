import type { ReleaseNoteId } from '../meta'
import type { ReleaseNotesMessages } from '../types'

export const enReleaseNotes = {
  title: "Changelog",
  count: "{count} release notes",
  loadMore: "Load more",
  latest: "Latest",
  pr: "PR #{number}",
  openedAt: "PR date",
  areas: "Areas",
  categories: {
    feature: "Feature",
    improvement: "Improvement",
    fix: "Fix",
    maintenance: "Maintenance",
    security: "Security"
  },
  areaLabels: {
    admin: "Admin",
    attachments: "Attachments",
    auth: "Auth",
    calendar: "Calendar",
    dashboard: "Dashboard",
    docs: "Docs",
    duty: "Duty",
    friends: "Friends",
    guide: "Guide",
    infra: "Infra",
    localization: "Localization",
    maintenance: "Maintenance",
    notifications: "Notifications",
    policy: "Policy",
    profile: "Profile",
    schedule: "Schedule",
    security: "Security",
    team: "Team",
    todo: "Todo",
    ui: "UI"
  },
  entries: {
    "pr-378": {
      title: "Improve friend menu experience",
      summary: "Makes the friend management menu easier to use: it opens next to the tapped friend, moves with the list while scrolling, and is simpler to close.",
      changes: [
        "Show the friend's name and a close button on the friend management menu.",
        "Dim the background on mobile so closing by tapping outside feels natural.",
        "Keep the menu attached to the friend list while scrolling."
      ]
    },
    "pr-377": {
      title: "Fix friend menu position on mobile",
      summary: "Fixes the friend management menu opening far away from its button after scrolling on mobile, and keeps it fully visible near the bottom of the screen.",
      changes: [
        "Open the friend management menu right next to its button even after scrolling the friend list.",
        "Open the menu above the button when there is not enough space below."
      ]
    },
    "pr-376": {
      title: "Align tagged todo detail actions",
      summary: "Makes tagged todo detail modal actions match owner todos by focusing on tag removal and the same complete or reopen action.",
      changes: [
        "Remove the extra status choice buttons from tagged todo detail actions.",
        "Use the same complete and reopen buttons for tagged todos and owner todos."
      ]
    },
    "pr-374": {
      title: "Show todo action labels on mobile",
      summary: "Makes todo detail modal actions easier to understand on mobile by keeping the text labels visible next to their icons.",
      changes: [
        "Keep the board, edit, delete, complete, reopen, tag removal, and status action labels visible on narrow screens.",
        "Allow the modal footer actions to wrap while preserving comfortable mobile tap targets."
      ]
    },
    "pr-370": {
      title: "Improve mobile calendar header names",
      summary: "Keeps member names readable in the duty calendar header without pushing the month navigation or search control out of alignment.",
      changes: [
        "Reduce only the mobile profile avatar size so the member name has enough room.",
        "Keep the balanced three-column header grid so the month navigator remains centered and search stays usable."
      ]
    },
    "pr-369": {
      title: "Refresh the Dutypark app icon",
      summary: "Updates the app icon with the selected moon calendar artwork and adds cache-busted icon paths.",
      changes: [
        "Replace the favicon, Apple touch icon, Android/PWA icons, MS tile, Safari mask, and SVG mark with the refreshed moon calendar design.",
        "Use transparent-corner icon assets and versioned filenames so browsers and installed PWAs pick up the new artwork cleanly.",
        "Add the new icon next to the Dutypark wordmark in the authenticated header."
      ]
    },
    "pr-368": {
      title: "Clarify notification read states",
      summary: "Makes notification read and unread states easier to distinguish and keeps notification actions visible on mobile.",
      changes: [
        "Header notifications: show the mark-all-read action when unread items are loaded and add visible button borders.",
        "Notification list: add unread indicators with an accent bar, avatar dot, and stronger title contrast.",
        "Mobile actions: add short localized labels so read and delete actions remain visible on narrow screens."
      ]
    },
    "pr-367": {
      title: "Gate PR release notes before merge",
      summary: "Adds the missing modal button release notes and a PR check that catches missing release note entries before merge.",
      changes: [
        "Add PR #366 release note metadata and localized copy across supported languages.",
        "Add a PR-number-specific CI check that fails when a main-targeting PR lacks matching release note metadata or locale copy.",
        "Document the create-PR-then-add-release-note workflow for future PRs."
      ]
    },
    "pr-366": {
      title: "Normalize modal action buttons",
      summary: "Keeps todo and schedule modal save actions from collapsing into tall, narrow buttons on small screens.",
      changes: [
        "Todo detail: reuse the compact modal action footer in edit mode so cancel and save share the available width.",
        "Schedule detail: remove a shrink-wrapping wrapper around create/edit actions so mobile buttons stay horizontal."
      ]
    },
    "pr-364": {
      title: "Automate GitHub Releases from in-app release notes",
      summary: "Create GitHub Releases from the matching English in-app release note whenever a PR is merged into main.",
      changes: [
        "Add a GitHub Release workflow that runs on merged PRs and supports manual dispatch for recovery.",
        "Generate release tags, titles, and notes from release note metadata and English copy instead of the PR body.",
        "Document the future PR release note workflow and fail release preparation when the in-app note is missing."
      ]
    },
    "pr-362": {
      title: "Add in-app release notes",
      summary: "Add a localized guide changelog with one release note per merged PR and validation for future entries.",
      changes: [
        "Show release notes at the bottom of the guide page with five entries loaded at a time.",
        "Backfill PR-based release note metadata and localized copy across supported languages.",
        "Add validation for duplicate metadata, missing locale entries, and vue-i18n message compilation."
      ]
    },
    "pr-361": {
      title: "Improve calendar navigation and notification reads",
      summary: "Add reusable month navigation with swipe gestures for calendar headers.",
      changes: [
        "Calendar: add CalendarMonthNavigator and reuse it in duty and team calendar headers with previous/next controls and year-month picker access.",
        "Notifications: refresh dropdown notifications on open, capture the single unread notification id, and mark it read on close only when it is still the same single unread item.",
        "Copy and tests: add calendar aria-label translations and Pinia coverage for single-unread notification read behavior."
      ]
    },
    "pr-359": {
      title: "Show identical schedule times once",
      summary: "Updates schedule detail display so identical start and end times are shown once.",
      changes: [
        "Frontend: add a same-time guard in ScheduleList.vue before rendering a time range."
      ]
    },
    "pr-358": {
      title: "Add animated swipe navigation to mobile dock",
      summary: "Replace the dock's instant active-state flash with a sliding highlight indicator.",
      changes: [
        "Dock highlight animation.",
        "Move the active dock background to a shared sliding indicator that tracks the selected item.",
        "Recalculate indicator size and position on route changes, initial render, and resize."
      ]
    },
    "pr-357": {
      title: "Dependency update: follow-redirects 1.15.11 -> 1.16.0",
      summary: "Updated follow-redirects from 1.15.11 to 1.16.0 in frontend.",
      changes: [
        "Bumped follow-redirects from 1.15.11 to 1.16.0.",
        "Kept the dependency set current for maintenance and security health."
      ]
    },
    "pr-356": {
      title: "Dependency update: axios 1.13.5 -> 1.15.0",
      summary: "Updated axios from 1.13.5 to 1.15.0 in frontend.",
      changes: [
        "Bumped axios from 1.13.5 to 1.15.0.",
        "Kept the dependency set current for maintenance and security health."
      ]
    },
    "pr-355": {
      title: "Improve interactive calendar TODO and D-Day chips",
      summary: "Show more of calendar TODO titles before truncating them on small screens.",
      changes: [
        "Calendar TODO chips.",
        "Switch mobile TODO rendering to character-based truncation so short titles stay visible.",
        "Preserve full TODO titles through chip tooltips and accessibility labels."
      ]
    },
    "pr-354": {
      title: "Improve time parsing logging and refresh token user agents",
      summary: "Add richer schedule time parsing logs with request, normalized content, and parsed time details.",
      changes: [
        "Schedule time parsing.",
        "Add a response helper that formats request and parsing results into a single log line.",
        "Log both no-time and LLM parsing paths after the final response is built."
      ]
    },
    "pr-353": {
      title: "Dependency update: vite 7.3.1 -> 7.3.2",
      summary: "Updated vite from 7.3.1 to 7.3.2 in frontend.",
      changes: [
        "Bumped vite from 7.3.1 to 7.3.2.",
        "Kept the dependency set current for maintenance and security health."
      ]
    },
    "pr-351": {
      title: "Dependency update: lodash 4.17.21 -> 4.18.1",
      summary: "Updated lodash from 4.17.21 to 4.18.1 in frontend.",
      changes: [
        "Bumped lodash from 4.17.21 to 4.18.1.",
        "Kept the dependency set current for maintenance and security health."
      ]
    },
    "pr-352": {
      title: "Correct frontend local date drift",
      summary: "Fix the D-day editor and calendar flow so local date-only values no longer drift by one day.",
      changes: [
        "Duty D-day: replaced UTC-based date slicing with local date-only parsing and formatting in the D-day modal, detail modal, calendar matching, and list sorting.",
        "Admin dashboard: extracted local-date login counting into a dedicated helper and added regression coverage for the pre-9am Korea-time case.",
        "TODO/date utils: added safe date-only helpers, updated Kanban due-date rendering, and extended frontend date tests for date-only formatting."
      ]
    },
    "pr-350": {
      title: "Stabilize schedule search pagination",
      summary: "Remove the Hibernate collection fetch pagination warning from schedule search.",
      changes: [
        "Split schedule search into a paged schedule id query and a follow-up detail fetch.",
        "Preserve result ordering in the service when hydrating fetched schedules.",
        "Add regression coverage for tagged results, paging metadata, and same-start-time ordering."
      ]
    },
    "pr-349": {
      title: "Polish duty compare controls and search UI",
      summary: "Polish the duty view together experience with clearer active state, inline reset actions, and profile-aware compare chips.",
      changes: [
        "Duty compare UI: added clear actions in the duty type bar and compare modal, and refreshed other-duty chips in the calendar grid.",
        "Search controls: refined the duty header search field and removed the redundant icon inside the search modal input.",
        "API contract: extended other duty responses with memberId, hasProfilePhoto, and profilePhotoVersion and updated controller coverage."
      ]
    },
    "pr-348": {
      title: "Harden gemma-4 schedule time parsing and timeout config",
      summary: "Harden schedule time parsing for gemma-4 responses that prepend reasoning text before the final JSON payload.",
      changes: [
        "Schedule time parsing.",
        "Extract the final response-shaped JSON object even when reasoning text or example JSON appears before it.",
        "Add regression tests for gemma-4 response parsing and extend the time parsing integration test timeouts."
      ]
    },
    "pr-347": {
      title: "Polish friend card styling on dashboard and friends views",
      summary: "Remove the unnecessary schedule background treatment from dashboard friend cards.",
      changes: [
        "Dashboard.",
        "Remove the extra schedule background from friend schedule lines in the dashboard card list.",
        "Replace the abrupt dashboard header gradient swap with a smoother hover overlay transition."
      ]
    },
    "pr-346": {
      title: "Harden auth fallback and visibility rules",
      summary: "Harden authentication fallback paths so logout and authenticated requests still work correctly when cookies are the only valid credentials.",
      changes: [
        "Auth and security.",
        "Allow logout through the refresh-token cookie path and align auth controller/docs coverage with the runtime contract.",
        "Fall back to the access-token cookie when a bad bearer token is supplied so valid cookie auth still succeeds."
      ]
    },
    "pr-345": {
      title: "Harden notification fallback handling",
      summary: "Add generic notification payload fallbacks for unread, paged, and mark-as-read flows instead of dropping or rejecting invalid rows.",
      changes: [
        "Backend.",
        "Return version 0 generic payloads for missing or invalid notification payloads.",
        "Rename internal notification count methods around pending relationship requests."
      ]
    },
    "pr-344": {
      title: "Move API error and detailed push rendering to the frontend",
      summary: "Move localized API error copy and detailed push notification rendering into frontend-owned i18n paths.",
      changes: [
        "Frontend i18n and push rendering.",
        "Move locale helpers into shared frontend utilities and keep the locale switcher open after dismissing the locale suggestion flow.",
        "Fold API error copy into the locale message bundles and add frontend-side notification and push rendering helpers."
      ]
    },
    "pr-343": {
      title: "Move i18n rendering and notifications to the frontend",
      summary: "Move notification rendering, push copy, and API error localization out of the backend and into frontend-owned code paths.",
      changes: [
        "Notification architecture.",
        "Replace stored notification title and content text with typed payload snapshots plus payload versioning.",
        "Add frontend notification DTOs, renderer registry, and versioned message keys for each notification message."
      ]
    },
    "pr-342": {
      title: "Add app-wide English and Japanese localization",
      summary: "Add app-wide frontend localization infrastructure with Korean, English, and Japanese message bundles.",
      changes: [
        "Frontend i18n.",
        "Add Vue i18n setup, locale store handling, and language suggestion flow for first-time users.",
        "Localize dashboard, duty, todo, team, admin, guide, notification, auth, policy, and shared modal/components."
      ]
    },
    "pr-341": {
      title: "Relax mobile calendar D-Day truncation",
      summary: "Relax mobile calendar D-day truncation so titles remain readable for longer before collapsing into an ellipsis.",
      changes: [
        "Frontend / Duty calendar.",
        "Add a shared mobile text truncation helper for compact calendar cell content.",
        "Apply the mobile truncation rule to D-day titles in DutyCalendarContent."
      ]
    },
    "pr-338": {
      title: "Improve shared calendar day details and visibility hints",
      summary: "Open a single read-only day detail modal for shared calendars so long schedules and tags stay readable.",
      changes: [
        "Shared calendar day detail.",
        "Replace the per-schedule shared-calendar detail popup flow with the read-only day detail modal.",
        "Keep the shared day detail footer in a read-only state with a simple close action."
      ]
    },
    "pr-337": {
      title: "Sync day detail duty selection by date",
      summary: "Keep the day detail duty buttons in sync with the currently selected calendar date.",
      changes: [
        "Make the selected day duty in DutyView reactive to the current selectedDay and duties data instead of storing a stale snapshot.",
        "Reset DayDetailModal's local duty selection state when either the selected date or the incoming duty prop changes.",
        "Remove the one-time duty assignment from the day click handler so modal data always reflects the latest month state."
      ]
    },
    "pr-336": {
      title: "Dependency update: picomatch 4.0.3 -> 4.0.4",
      summary: "Updated picomatch from 4.0.3 to 4.0.4 in frontend.",
      changes: [
        "Bumped picomatch from 4.0.3 to 4.0.4.",
        "Kept the dependency set current for maintenance and security health."
      ]
    },
    "pr-335": {
      title: "Unify frontend modal patterns",
      summary: "Unify modal shells, headers, bodies, and footer action spacing across the frontend.",
      changes: [
        "Common modal foundation.",
        "Extend BaseModal for shared panel styling.",
        "Add shared modal body/action/input utility classes in frontend/src/style.css."
      ]
    },
    "pr-334": {
      title: "Standardize modal shells and compact mobile duty calendar cells",
      summary: "Standardize modal shell, overlay, and safe-area sizing across shared and feature-specific dialogs.",
      changes: [
        "Frontend / Modal foundation.",
        "Add a shared BaseModal component with size, height, overlay padding, z-index, and backdrop handling options.",
        "Move modal overlay and container sizing into shared CSS utilities, including viewport-safe gutters and nav-safe padding variants."
      ]
    },
    "pr-333": {
      title: "Add todo tagging and tagged-member status updates",
      summary: "Add todo tagging so owners can tag friends and tagged members can update todo status across board and duty flows.",
      changes: [
        "Backend.",
        "Add todo tag persistence, DTO fields, controller endpoints, and service logic for tag creation, removal, and tagged-member status changes.",
        "Allow status-only todo moves when a tagged member changes columns, and extend attachment permissions for TODO contexts."
      ]
    },
    "pr-332": {
      title: "Improve member created date backfill heuristics",
      summary: "Rework the member created-date recovery migration so it no longer relies on refresh token history.",
      changes: [
        "Backend / Migration.",
        "Add a re-backfill migration for member.created_date recovery.",
        "Infer earlier schedule timestamps from legacy UUID and ULID-backed schedule ids when old schedule audit columns were flattened by a past migration."
      ]
    },
    "pr-331": {
      title: "Add admin member detail stats modal",
      summary: "Add an admin member detail API and modal that surfaces account, activity, schedule, todo, relationship, D-Day, and notification stats.",
      changes: [
        "Backend / Admin API.",
        "Add GET /admin/api/members/{'{'}memberId{'}'} with aggregated member detail fields.",
        "Collect session, schedule, todo, friend, manager, D-Day, and notification counts for the selected member."
      ]
    },
    "pr-330": {
      title: "Polish schedule tag chip layout and list actions",
      summary: "Improve schedule tag chip sizing and spacing across the schedule list, duty calendar, and friend tag selector.",
      changes: [
        "Frontend / Schedule list.",
        "Rework the schedule item header so edit, delete, and untag actions stay grouped without breaking tag chip layout.",
        "Let tagged member chips use the available width more reliably inside the schedule list."
      ]
    },
    "pr-329": {
      title: "Polish mobile day detail modal layout and tag editing",
      summary: "Rebalance mobile day detail modal spacing and safe-area handling so schedule list and edit modes fit better on iPhone-sized viewports.",
      changes: [
        "Frontend.",
        "Turn the day detail modal into a more reliable mobile bottom-sheet layout with mode-specific shell/footer spacing and larger schedule form controls.",
        "Tighten FriendTagSelector, schedule tag chips, and calendar tag presentation for mobile editing, including tag-chip click-to-edit behavior."
      ]
    },
    "pr-328": {
      title: "Improve schedule friend tagging and tagged member previews",
      summary: "Improve how schedule friend tags are selected, persisted, and displayed across duty, calendar, and dashboard surfaces.",
      changes: [
        "Frontend.",
        "Add a reusable FriendTagSelector with search, selected-only filtering, reset confirmation, unavailable-tag fallback, and responsive chip/list layouts.",
        "Update schedule forms, lists, modals, calendar content, and related member-facing views to show tagged friend avatars and cleaner tag presentation."
      ]
    },
    "pr-326": {
      title: "Handle Naver OAuth token exchange errors",
      summary: "Fix Naver OAuth token exchange failures in production by wiring the missing app container environment variables.",
      changes: [
        "Ops.",
        "Pass NAVER_CLIENT_ID and NAVER_CLIENT_SECRET into the production app container.",
        "Backend."
      ]
    },
    "pr-325": {
      title: "Add Naver social login and normalize social account links",
      summary: "Add Naver social login support across backend and SPA login/signup flows.",
      changes: [
        "Backend OAuth: add Naver OAuth config, token/userinfo clients, callback handling, and social-account-specific exceptions.",
        "Signup and linking: require explicit terms/privacy versions, harden duplicate social link handling, and preserve existing DTO response fields through a dedicated assembler.",
        "Persistence: add , backfill legacy Kakao/Naver IDs, then drop legacy member columns in follow-up migration."
      ]
    },
    "pr-324": {
      title: "Migrate hardcoded theme styles to token utility classes",
      summary: "Migrate inline/static hardcoded color and style bindings to shared dp-* token utility classes across the Vue frontend.",
      changes: [
        "Theme/token refactor.",
        "Replace direct style/color literals in major views and components with utility classes and tokenized variables.",
        "Expand token coverage in frontend/src/style.css (including input border token)."
      ]
    },
    "pr-323": {
      title: "Harden iOS PWA notification badge synchronization",
      summary: "Harden iOS PWA app badge synchronization when resuming the app.",
      changes: [
        "Frontend notification store.",
        "Added robust app badge fallback logic for navigator and service worker badge APIs.",
        "Added resume-sync triggers for focus and pageshow in addition to visibilitychange."
      ]
    },
    "pr-322": {
      title: "Sync iOS PWA app badge with server unread count",
      summary: "Fix stale iOS PWA app badge counts when notifications were read on another device.",
      changes: [
        "Frontend notification store.",
        "Call app badge sync immediately after unread-count API responses.",
        "Call app badge sync when unread list is fetched."
      ]
    },
    "pr-320": {
      title: "Dependency update: rollup 4.55.1 -> 4.59.0",
      summary: "Updated rollup from 4.55.1 to 4.59.0 in frontend.",
      changes: [
        "Bumped rollup from 4.55.1 to 4.59.0.",
        "Kept the dependency set current for maintenance and security health."
      ]
    },
    "pr-321": {
      title: "Remove required PAT token from CI checkout",
      summary: "Remove mandatory PAT token usage in checkout so Dependabot pull requests can run CI without repository secret access.",
      changes: [
        "CI workflow (.github/workflows/gradle.yml).",
        "Removed token: ${'{'}{'{'} secrets.PAT_TOKEN {'}'}{'}'} from the checkout step.",
        "Kept submodules: recursive and fetch-depth: 0 unchanged."
      ]
    },
    "pr-319": {
      title: "Harden D-Day visibility checks and reduce Slack noise",
      summary: "Enforce calendar visibility checks before serving D-Day read endpoints.",
      changes: [
        "Keep private D-Day filtering behavior intact after visibility checks.",
        "Exclude MethodArgumentTypeMismatchException from Slack error notifications.",
        "Refactor ignored-exception policy into a dedicated collection for easier maintenance."
      ]
    },
    "pr-317": {
      title: "Dependency update: axios 1.13.2 -> 1.13.5",
      summary: "Updated axios from 1.13.2 to 1.13.5 in frontend.",
      changes: [
        "Bumped axios from 1.13.2 to 1.13.5.",
        "Kept the dependency set current for maintenance and security health."
      ]
    },
    "pr-318": {
      title: "Use JPEG instead of PNG for cropped profile photos",
      summary: "Profile photo crop was converting images to PNG (lossless), inflating file size significantly (e.g., 2.9MB JPEG → 10MB+ PNG).",
      changes: [
        "This exceeded nginx client_max_body_size 10M, causing 413 Content Too Large errors.",
        "Changed to JPEG with 0.9 quality, keeping file sizes small while maintaining visual quality."
      ]
    },
    "pr-316": {
      title: "Send slack notification on LLM parsing error",
      summary: "Add Slack notification when LLM time parsing fails.",
      changes: [
        "Add errorMessage and rawResponse fields to parsing response for debugging.",
        "Add tests for exception and parsing failure cases."
      ]
    },
    "pr-314": {
      title: "Split large Vue components and batch dashboard loading",
      summary: "Split large DutyView component into smaller, focused components (DDayList, DutyCalendarContent, DutyHeaderControls, DutyTodoRow, DutyTypesBar, ScheduleForm, ScheduleList, UntagConfirmModal).",
      changes: [
        "Split TeamManageView into separate modal components (BatchUploadModal, DutyTypeModal, MemberSearchModal).",
        "Split DayDetailModal into smaller components for better maintainability.",
        "Batch dashboard schedule loading to reduce N+1 queries."
      ]
    },
    "pr-313": {
      title: "Improve test coverage and optimize codebase",
      summary: "Expand test coverage for controllers and services across multiple modules.",
      changes: [
        "Tests: Added comprehensive tests for Admin, Attachment, Auth, Dashboard, Duty, Member, Notification, Policy, Push, Schedule, Security, Team, and Todo modules.",
        "Performance: Replaced in-memory filtering with database subquery in MemberRepository.",
        "Code Quality: Removed unused logger declarations and verbose logging statements."
      ]
    },
    "pr-311": {
      title: "Add web push notification support",
      summary: "Add Web Push notification support for friend/family requests and schedule tags.",
      changes: [
        "Backend: WebPushService, PushController, VAPID configuration.",
        "Frontend: Service Worker, usePushNotification composable, push API client.",
        "Database: Add push columns to refresh_token table."
      ]
    },
    "pr-309": {
      title: "Improve todo board UX and fix calendar/todo positioning issues",
      summary: "Improve todo board layout with independent column scrolling for better UX.",
      changes: [
        "Fix todo position calculation when moving across columns via drag-drop.",
        "Reset date to today when switching calendars and hide tag controls on others' calendar."
      ]
    },
    "pr-308": {
      title: "Security fixes and UX improvements",
      summary: "Add empty state message for friends section in dashboard.",
      changes: [
        "Mask Gemini API key in log output for security.",
        "Handle impersonation session expiration with countdown timer and auto-restore.",
        "Validate DutyType ownership before team management operations to prevent unauthorized access."
      ]
    },
    "pr-307": {
      title: "Add auxiliary account creation feature",
      summary: "Add auxiliary account creation feature for managing child/side-business schedules.",
      changes: [
        "Add POST /api/members/auxiliary endpoint in MemberController.",
        "Add createAuxiliaryAccount method in MemberService.",
        "Add createAuxiliaryAccount API function in member.ts."
      ]
    },
    "pr-306": {
      title: "Family demote, todo modal, and timezone fixes",
      summary: "Add ability to demote family member to regular friend.",
      changes: [
        "Fix todo detail modal opening when clicking due todo in calendar.",
        "Fix timezone issue showing 09:00 for date-only due dates."
      ]
    },
    "pr-305": {
      title: "Optimize AI schedule time parsing with pre-filter and configurable rate limits",
      summary: "Add pre-filter to skip LLM calls for schedules without time indicators (numbers, Korean time words like 한/두/세, 정오/자정).",
      changes: [
        "Extract hardcoded AI rate limits (rpm/rpd) to application.yml configuration.",
        "Increase rate limits from 10 RPM / 20 RPD to 30 RPM / 14400 RPD."
      ]
    },
    "pr-304": {
      title: "Switch from Gemini to Gemma model with enhanced prompts",
      summary: "Switch AI model from Gemini 2.5 Flash Lite to Gemma 3 27B due to reduced Gemini free quota.",
      changes: [
        "ScheduleTimeParsingService.kt: Replace instruction-based prompt with example-based prompt.",
        "Application.yml: Change model from gemini-2.5-flash-lite to gemma-3-27b-it.",
        "ScheduleTimeParsingServiceTest.kt: Update test to verify floor numbers aren't parsed as time."
      ]
    },
    "pr-303": {
      title: "Upgrade Spring Boot 4.0 and Gemini 2.5 Flash",
      summary: "Upgrade Spring Boot from 3.5.6 to 4.0.1 with related dependency changes.",
      changes: [
        "Spring Boot 3.5.6 → 4.0.1.",
        "Spring AI 1.0.3 → 2.0.0-M1.",
        "Jackson module: com.fasterxml.jackson.module → tools.jackson.module."
      ]
    },
    "pr-302": {
      title: "Upgrade Java 21 to 25",
      summary: "Upgrade Java toolchain from 21 to 25.",
      changes: [
        "Upgrade Kotlin from 2.1.10 to 2.3.0 (Java 25 JVM target support).",
        "Upgrade Gradle from 8.11 to 9.2.1 (Java 25 compatibility).",
        "Upgrade asciidoctor plugin from 3.3.2 to 4.0.5."
      ]
    },
    "pr-301": {
      title: "Frontend improvements: todo calendar integration, code cleanup, and bug fixes",
      summary: "Display todos with due dates on the calendar view for better visibility.",
      changes: [
        "Remove dead code and unused legacy API functions from frontend.",
        "Simplify todo filter UI (IN_PROGRESS always shown, TODO toggle only).",
        "Fix timing issue with duty type counts by using computed property."
      ]
    },
    "pr-300": {
      title: "Add kanban board for todo management",
      summary: "Add kanban board view (/todo) with drag-and-drop support for todo management.",
      changes: [
        "New TodoBoardView.vue kanban board page with responsive design.",
        "KanbanCard.vue and KanbanColumn.vue components for drag-and-drop.",
        "Todo filter toggle for completed/hold items visibility."
      ]
    },
    "pr-296": {
      title: "Add login rate limiting to prevent brute force attacks",
      summary: "Implement DB-based login rate limiting with IP + email combination.",
      changes: [
        "Add LoginAttempt entity and repository for tracking failed attempts.",
        "Add LoginAttemptService with configurable limits (max attempts, window duration).",
        "Integrate rate limiting into AuthService and AuthController."
      ]
    },
    "pr-295": {
      title: "Improve admin session list and calendar UI enhancements",
      summary: "Add pulse-glow animation for calendar date highlight to improve visual feedback.",
      changes: [
        "Improve admin session list with collapsible UI and better styling.",
        "Add created date to session token list for better token management."
      ]
    },
    "pr-294": {
      title: "Consolidate CSS variables and improve dark mode styling",
      summary: "Consolidate CSS variables and remove dark mode duplication for cleaner maintainability.",
      changes: [
        "Fix navigation to correct date when clicking schedule notification on calendar page.",
        "Improve duty type button border visibility in dark mode."
      ]
    },
    "pr-293": {
      title: "Enhance UI components, add user guide, and refactor modal styles",
      summary: "Add comprehensive user guide page (/guide) with collapsible sections covering all app features.",
      changes: [
        "New Feature: User guide page with help documentation for Dashboard, Calendar, Team, Friends, and Settings.",
        "Refactor: Common modal styles extracted to style.css for consistency across all modals.",
        "Fix: Calendar grid hover effect now respects clickable prop (disabled on view-only calendars)."
      ]
    },
    "pr-292": {
      title: "Resolve impersonation banner and notification dropdown issues",
      summary: "Fix impersonation banner being hidden by fixed header.",
      changes: [
        "Fix notification dropdown click events not working due to z-index stacking context issues.",
        "Include schedule title in SCHEDULE_TAGGED notification title."
      ]
    },
    "pr-291": {
      title: "Add notification system, friends page, and sticky header",
      summary: "Add notification system with polling-based updates.",
      changes: [
        "Add dedicated friends management page and simplify dashboard.",
        "Add friend request count badge and improve notification navigation.",
        "Make header sticky at top with theme toggle button."
      ]
    },
    "pr-289": {
      title: "Dependency update: preact 10.27.2 -> 10.28.2",
      summary: "Updated preact from 10.27.2 to 10.28.2 in frontend.",
      changes: [
        "Bumped preact from 10.27.2 to 10.28.2.",
        "Kept the dependency set current for maintenance and security health."
      ]
    },
    "pr-290": {
      title: "Add visibility-based icon colors and clean up unused code",
      summary: "Add visibility-based icon colors for schedule creation (lock icon reflects privacy setting).",
      changes: [
        "Remove unused code across backend and frontend (21 files, net -249 lines)."
      ]
    },
    "pr-288": {
      title: "Improve intro showcase layout and mockup positioning",
      summary: "Add margin between hero title and subtitle for better spacing.",
      changes: [
        "Fix mockup frame size to be consistent across all features (200px mobile, 260px desktop).",
        "Remove transform animations from mockup for stable positioning during scroll.",
        "Add min-height to text area to prevent mockup position shifts between sections."
      ]
    },
    "pr-287": {
      title: "Apple-style intro page with scroll animations",
      summary: "Add Apple-style intro page with scroll animations and privacy/terms pages.",
      changes: [
        "Add hero section with animated entrance effects.",
        "Implement sticky scroll showcase for feature highlights.",
        "Features stay centered while scrolling with crossfade transitions at 80-100% progress."
      ]
    },
    "pr-286": {
      title: "Add sequential duty input mode with quick buttons",
      summary: "Add sequential duty input mode for faster duty editing.",
      changes: [
        "Add focused day concept (starts at day 1 in edit mode).",
        "Show day navigator with arrow buttons ``.",
        "Click duty button → apply to focused day → auto-move to next day."
      ]
    },
    "pr-285": {
      title: "Add profile photo URL versioning for cache busting",
      summary: "Add URL versioning strategy for profile photo cache management.",
      changes: [
        "Add profile_photo_version column via Flyway migration (V2.1.3).",
        "Add profilePhotoVersion field to Member entity with increment method.",
        "Update ProfilePhotoService to increment version on upload."
      ]
    },
    "pr-284": {
      title: "Remove unused code and fix data consistency issues",
      summary: "Remove unused methods and types across backend and frontend.",
      changes: [
        "Remove MemberDto.ofSimple() unused method.",
        "Remove AttachmentRepository.findFirstByContextTypeAndContextId() and existsByContextTypeAndContextId() unused methods.",
        "Remove SimpleMemberDto unnecessary secondary constructor."
      ]
    },
    "pr-283": {
      title: "Add account impersonation for managed members",
      summary: "Add impersonate/restore functionality allowing managers to switch to managed accounts.",
      changes: [
        "Add isImpersonating and originalMemberId fields to LoginMember.",
        "Add JWT impersonation token support in JwtProvider.",
        "Add POST /api/auth/impersonate/{'{'}targetMemberId{'}'} and POST /api/auth/restore endpoints."
      ]
    },
    "pr-282": {
      title: "Add server-side pagination and optimize user-agent parsing",
      summary: "Add server-side pagination to admin member list with debounced search.",
      changes: [
        "Add AdminMemberDto with member info and associated tokens.",
        "Add AdminService with paginated member query.",
        "Add MemberRepository custom queries with NULLS LAST for proper sorting."
      ]
    },
    "pr-281": {
      title: "Improve search modal UX and add hover effects",
      summary: "Add in-modal search functionality to re-search without closing modal.",
      changes: [
        "Add search input field in modal header for changing search query.",
        "Add loading state indicator during search.",
        "Reduce modal height on PC (70vh) for better visibility."
      ]
    },
    "pr-280": {
      title: "Calendar improvements and code cleanup",
      summary: "Add quick navigation to current month in duty calendar (click footer button or member name).",
      changes: [
        "Fix CalendarView to always return 42 days (6 weeks) for consistent layout.",
        "Use backend calendar API in frontend for proper index alignment with holidays.",
        "Prevent duplicate Kakao OAuth requests on rapid clicks."
      ]
    },
    "pr-279": {
      title: "Migrate authentication from localStorage to HttpOnly cookies",
      summary: "Migrate token storage from localStorage to HttpOnly cookies for XSS protection.",
      changes: [
        "Add CookieConfig.kt and CookieService.kt for cookie management.",
        "Update AuthController to set HttpOnly cookies on login/refresh.",
        "Add {'@'}Login requirement to logout endpoint."
      ]
    },
    "pr-278": {
      title: "Simplify todo UI and improve calendar design",
      summary: "Simplify todo list UI by removing drag-and-drop functionality.",
      changes: [
        "Remove SortableJS drag-and-drop from todo bubbles.",
        "Convert to simple clickable list layout with compact styling.",
        "Reduce visual complexity while maintaining functionality."
      ]
    },
    "pr-277": {
      title: "Migrate to Vue 3 SPA architecture",
      summary: "Vue 3 SPA with Composition API and TypeScript.",
      changes: [
        "Vite for fast dev server with HMR (Hot Module Replacement).",
        "Pinia for state management.",
        "Tailwind CSS 4 with custom design tokens."
      ]
    },
    "pr-276": {
      title: "Consolidate attachment uploader and update documentation",
      summary: "Consolidate duplicate Uppy uploader initialization into shared helper.",
      changes: [
        "Extract ~300 lines of duplicate Uppy initialization logic from 3 modal files into createUppyUploader function in attachment-helpers.js.",
        "Total code reduction: 764 lines (38%).",
        "Affected files:."
      ]
    },
    "pr-274": {
      title: "Add todo attachments and fix server warnings",
      summary: "Add file attachment feature to TODO (upload, download, delete).",
      changes: [
        "Add file upload functionality with Uppy integration.",
        "Add download button for attachments.",
        "Add delete functionality for attachments."
      ]
    },
    "pr-269": {
      title: "Optimize holiday lookup in duty initialization",
      summary: "Optimize holiday lookup performance by eliminating redundant API calls during weekday duty initialization.",
      changes: [
        "Before: Called holidayService.findHolidays() for each date in calendar view (N times).",
        "After: Call once and build a Set for O(1) lookup.",
        "Reduces time complexity from O(n²) to O(n)."
      ]
    },
    "pr-268": {
      title: "Implement schedule attachment system with upload, thumbnail generation, and permission control",
      summary: "File upload with Uppy.js integration and upload session management.",
      changes: [
        "Automatic thumbnail generation for images (async with status tracking).",
        "Permission-based access control for attachments.",
        "Inline image viewer for schedule attachments."
      ]
    },
    "pr-267": {
      title: "Improve Vue reactivity and UX enhancements",
      summary: "Fix Vue.js reactivity issue in hasSchedule method.",
      changes: [
        "Change hasSchedule from higher-order function pattern to direct method to ensure proper Vue reactivity tracking.",
        "Resolves issue where has-schedule CSS class was incorrectly applied.",
        "Skip API call and success popup when selecting already-assigned duty type."
      ]
    },
    "pr-266": {
      title: "Improve codebase quality and security",
      summary: "Upgrade jjwt to 0.12.6 with updated API for security enhancements.",
      changes: [
        "Add SameSite=Lax cookie attribute for CSRF protection.",
        "Replace deprecated AntPathRequestMatcher with AntPathMatcher.",
        "Improve 404 error responses with detailed error messages."
      ]
    },
    "pr-265": {
      title: "Show only active todos by default in overview",
      summary: "Show only active todos by default in the overview modal.",
      changes: [
        "Set todoOverviewFilters.completed default to false in duty.js.",
        "Update todo count display to show only active todos count."
      ]
    },
    "pr-264": {
      title: "Enable overview todo drag reorder",
      summary: "Allow dragging active todos inside overview modal with familiar handle.",
      changes: [
        "Sync reorder between overview and main list and persist order to backend."
      ]
    },
    "pr-263": {
      title: "Add loading spinners to improve UX",
      summary: "Add loading state indicators to prevent layout shifts and improve UX.",
      changes: [
        "Todo List: Show spinner while loading todos instead of flickering empty state.",
        "Dashboard - My Info: Add spinner for duty type and schedule data, keep static elements (date, labels) visible.",
        "Dashboard - Friend List: Add spinner during friend data fetch."
      ]
    },
    "pr-262": {
      title: "Prevent auto-focus on duty type modal input for mobile",
      summary: "Refactor duty type modal initialization to prevent auto-focus on mobile Safari.",
      changes: [
        "Add initDutyTypeModal() function to prevent keyboard popup on mobile Safari.",
        "Use temporary readonly attribute to block auto-focus during modal initialization.",
        "Apply blur() to ensure input loses focus immediately on modal open."
      ]
    },
    "pr-261": {
      title: "Todo completion tracking and duty modal improvements",
      summary: "Add todo completion status tracking with ACTIVE/COMPLETED states.",
      changes: [
        "Add TodoStatus enum (ACTIVE, COMPLETED).",
        "Add completion date tracking.",
        "Add endpoints for completing/reopening todos (PATCH /api/todos/{'{'}id{'}'}/complete, /reopen)."
      ]
    },
    "pr-260": {
      title: "Enhance duty type management with color picker and mobile optimization",
      summary: "Replace Color enum with custom color picker using Pickr library for unlimited color selection.",
      changes: [
        "Add real-time preview in duty type modals showing selected color and name.",
        "Optimize modals for mobile-first design with larger fonts and touch-friendly controls.",
        "Implement Bootstrap utility classes over inline styles throughout the application."
      ]
    },
    "pr-259": {
      title: "Manager now can search on managee's calendar",
      summary: "Refactor: optimize schedule time parsing with early content filtering.",
      changes: [
        "Updated the related Auth, Security, Calendar, Schedule, Team, Friends code paths for this release."
      ]
    },
    "pr-258": {
      title: "Migrate to Docker-based deployment with monitoring stack",
      summary: "Migrate to Docker-based deployment with monitoring stack.",
      changes: [
        "Updated the related Auth, Security, Calendar, Schedule, Notifications, Admin code paths for this release."
      ]
    },
    "pr-257": {
      title: "UI improvements and bug fixes for friend selection and scheduling",
      summary: "Fix scroll to top issue when tagging friends in schedule modal.",
      changes: [
        "Fix friend tagging scroll issue: Changed href=\"#\" to href=\"javascript:void(0)\" to prevent page scroll.",
        "Enhanced friend selection UX: Added hover effects and cursor pointer for better interaction feedback.",
        "Fixed checkbox behavior: Allow deselecting checked checkboxes even when max selection reached."
      ]
    },
    "pr-254": {
      title: "Add support for null dutyType and explicit off-day flag in …",
      summary: "…duties.",
      changes: [
        "Updated the related Team, Dashboard, Infra code paths for this release."
      ]
    },
    "pr-253": {
      title: "Work type weekdays filled by lazy init automatically",
      summary: "Added work type weekdays filled by lazy init automatically.",
      changes: [
        "Updated the related Team, Admin, Infra code paths for this release."
      ]
    },
    "pr-252": {
      title: "Show combined duty schedules",
      summary: "Added show combined duty schedules.",
      changes: [
        "Updated the related Schedule, Friends, Dashboard, UI code paths for this release."
      ]
    },
    "pr-251": {
      title: "Improve schedule tags showing functionality",
      summary: "Improve schedule tags showing functionality.",
      changes: [
        "Updated the related Schedule, Dashboard, UI code paths for this release."
      ]
    },
    "pr-250": {
      title: "Some design enhancement",
      summary: "Improved some design enhancement.",
      changes: [
        "Updated the related UI code paths for this release."
      ]
    },
    "pr-249": {
      title: "Split duty.html into feature-scoped modules",
      summary: "Updated split duty.html into feature-scoped modules.",
      changes: [
        "Updated the related Calendar, Schedule, Todo, Team, Friends, Dashboard code paths for this release."
      ]
    },
    "pr-247": {
      title: "Search UX improved",
      summary: "Improved search UX improved.",
      changes: [
        "Updated the related UI code paths for this release."
      ]
    },
    "pr-246": {
      title: "CalendarView.kt",
      summary: "Updated calendarView.kt.",
      changes: [
        "Updated the related Calendar, Schedule, Team, UI code paths for this release."
      ]
    },
    "pr-245": {
      title: "Schedule detail speech bubble",
      summary: "When click schedule chat icon which has schedule detail, it will show schedule detail text pop up.",
      changes: [
        "Can edit schedule start date on schedule edit mode."
      ]
    },
    "pr-244": {
      title: "When update D-Days, it shows the modification on calendar right …",
      summary: "…away.",
      changes: [
        "Updated the related Calendar code paths for this release."
      ]
    },
    "pr-243": {
      title: "Team schedule",
      summary: "Added team schedule.",
      changes: [
        "Updated the related Auth, Security, Calendar, Schedule, Todo, Team code paths for this release."
      ]
    },
    "pr-242": {
      title: "Ensure Duty is deleted when DutyType is removed",
      summary: "Updated ensure Duty is deleted when DutyType is removed.",
      changes: [
        "Updated the related Notifications, Infra code paths for this release."
      ]
    },
    "pr-241": {
      title: "Dept => team",
      summary: "Updated dept => team.",
      changes: [
        "Updated the related Auth, Security, Calendar, Schedule, Team, Friends code paths for this release."
      ]
    },
    "pr-240": {
      title: "Hotfix",
      summary: "Improved hotfix.",
      changes: [
        "Updated the related Notifications, Dashboard code paths for this release."
      ]
    },
    "pr-239": {
      title: "My team page",
      summary: "Improved my team page.",
      changes: [
        "Updated the related Auth, Security, Schedule, Todo, Team, Friends code paths for this release."
      ]
    },
    "pr-238": {
      title: "Manager feature",
      summary: "Improved manager feature.",
      changes: [
        "Updated the related Auth, Security, Calendar, Schedule, Todo, Team code paths for this release."
      ]
    },
    "pr-237": {
      title: "Active menu on dock",
      summary: "Improved active menu on dock.",
      changes: [
        "Updated the related Schedule, UI code paths for this release."
      ]
    },
    "pr-236": {
      title: "Use LLM to extract time data from schedule title",
      summary: "Improved use LLM to extract time data from schedule title.",
      changes: [
        "Updated the related Schedule, Todo, Team, Friends, UI, Infra code paths for this release."
      ]
    },
    "pr-235": {
      title: "Minor UI/UX Enhancement",
      summary: "Improved minor UI/UX Enhancement.",
      changes: [
        "Updated the related Dashboard, UI code paths for this release."
      ]
    },
    "pr-234": {
      title: "# temporal fix",
      summary: "Improved # temporal fix.",
      changes: [
        "Updated the related Auth, Dashboard, UI code paths for this release."
      ]
    },
    "pr-233": {
      title: "Minor design modifications",
      summary: "Improved minor design modifications.",
      changes: [
        "Updated the related UI code paths for this release."
      ]
    },
    "pr-226": {
      title: "Mobile friendly app-like UI",
      summary: "Improved mobile friendly app-like UI.",
      changes: [
        "Updated the related Auth, Friends, UI code paths for this release."
      ]
    },
    "pr-225": {
      title: "Pin friend",
      summary: "Improved pin friend.",
      changes: [
        "Updated the related Team, Friends, Admin, Dashboard, UI, Infra code paths for this release."
      ]
    },
    "pr-224": {
      title: "Dashboard better UX",
      summary: "Improved dashboard better UX.",
      changes: [
        "Updated the related Auth, Schedule, Team, Dashboard, UI code paths for this release."
      ]
    },
    "pr-222": {
      title: "Batch upload department duty",
      summary: "Improved batch upload department duty.",
      changes: [
        "Updated the related Calendar, Team, Admin, Attachments, Dashboard, UI code paths for this release."
      ]
    },
    "pr-221": {
      title: "Dashboard",
      summary: "Whole new dashboard TODO: dashboard for guest, newbie without department yet.",
      changes: [
        "Updated the related Schedule, Todo, Team, Friends, Admin, Dashboard code paths for this release."
      ]
    },
    "pr-220": {
      title: "1. duty batch refactor 2. shows duty counts",
      summary: "Duty batch refactor duty batch bug fix duty UI/UX enhanced Kotlin version up.",
      changes: [
        "Updated the related Calendar, UI, Infra code paths for this release."
      ]
    },
    "pr-219": {
      title: "Automate Work Schedule Updates from Uploaded Timetables",
      summary: "Improved automate Work Schedule Updates from Uploaded Timetables.",
      changes: [
        "Updated the related Calendar, Schedule, Team, Admin, Attachments, UI code paths for this release."
      ]
    },
    "pr-218": {
      title: "Dutypark db compose file",
      summary: "Updated dutypark db compose file.",
      changes: [
        "Updated the related Attachments, UI, Infra, Docs code paths for this release."
      ]
    },
    "pr-213": {
      title: "Schedule description",
      summary: "Improved schedule description.",
      changes: [
        "Updated the related Calendar, Schedule, UI, Infra code paths for this release."
      ]
    },
    "pr-211": {
      title: "Update bootstrap icons version v1.3.0 -> v1.11.0",
      summary: "Update bootstrap icons version v1.3.0 -> v1.11.0.",
      changes: [
        "Updated the related Auth, Calendar, Schedule, Todo, Team, Friends code paths for this release."
      ]
    },
    "pr-210": {
      title: "Say good by to input[type=\"month\"], search result click event",
      summary: "Improved say good by to input[type=\"month\"], search result click event.",
      changes: [
        "Updated the related Calendar, Schedule, UI, Infra, Docs code paths for this release."
      ]
    },
    "pr-208": {
      title: "Restrict page numbers on search result",
      summary: "In case of too many pages(20+), it was too wide and design was ugly.",
      changes: [
        "So, restrict pages to show."
      ]
    },
    "pr-207": {
      title: "Schedule search",
      summary: "Improved schedule search.",
      changes: [
        "Updated the related Schedule, Friends, UI code paths for this release."
      ]
    },
    "pr-206": {
      title: "Duty batch update",
      summary: "Improved duty batch update.",
      changes: [
        "Updated the related Auth, Security, Calendar, UI, Infra code paths for this release."
      ]
    },
    "pr-204": {
      title: "Spring boot 3.3.5, JDK 21",
      summary: "Improved spring boot 3.3.5, JDK 21.",
      changes: [
        "Updated the related UI, Infra code paths for this release."
      ]
    },
    "pr-202": {
      title: "Ensure D-Days are loaded before checking duties on calendar",
      summary: "Fixed ensure D-Days are loaded before checking duties on calendar.",
      changes: [
        "Updated the related Calendar code paths for this release."
      ]
    },
    "pr-201": {
      title: "Hotfix fix some bugs and enhance ui",
      summary: "Detailed changes are on its' commit messages.",
      changes: [
        "Updated the related Notifications, Localization, UI code paths for this release."
      ]
    },
    "pr-200": {
      title: "TODO feature",
      summary: "Improved tODO feature.",
      changes: [
        "Updated the related Todo, UI, Infra, Docs code paths for this release."
      ]
    },
    "pr-198": {
      title: "Typo",
      summary: "Fixed typo.",
      changes: [
        "Updated the related Maintenance code paths for this release."
      ]
    },
    "pr-196": {
      title: "Evict holiday cache when reset info",
      summary: "Fixed evict holiday cache when reset info.",
      changes: [
        "Updated the related Calendar code paths for this release."
      ]
    },
    "pr-195": {
      title: "Do not show other schedules on edit mode",
      summary: "Fixed do not show other schedules on edit mode.",
      changes: [
        "Updated the related Schedule code paths for this release."
      ]
    },
    "pr-194": {
      title: "Dependency update: actions/download-artifact 2 -> 4.1.7",
      summary: "Updated actions/download-artifact from 2 to 4.1.7 in .github/workflows.",
      changes: [
        "Bumped actions/download-artifact from 2 to 4.1.7.",
        "Kept the dependency set current for maintenance and security health."
      ]
    },
    "pr-193": {
      title: "Can change default duty name",
      summary: "Added can change default duty name.",
      changes: [
        "Updated the related Team, Admin, Infra code paths for this release."
      ]
    },
    "pr-192": {
      title: "Untag confirmation message",
      summary: "Added untag confirmation message.",
      changes: [
        "Updated the related Schedule code paths for this release."
      ]
    },
    "pr-191": {
      title: "Hotfix (slack error notification, schedule delete UX)",
      summary: "Improved hotfix (slack error notification, schedule delete UX).",
      changes: [
        "Updated the related Auth, Security, Schedule, Friends, Notifications, UI code paths for this release."
      ]
    },
    "pr-190": {
      title: "Bootstrap .map file NoResourceFoundException resolved",
      summary: "Fixed bootstrap .map file NoResourceFoundException resolved.",
      changes: [
        "Updated the related Auth, Security, Schedule, Attachments, UI, Infra code paths for this release."
      ]
    },
    "pr-189": {
      title: "Member name is not unique anymore",
      summary: "Fixed member name is not unique anymore.",
      changes: [
        "Updated the related Infra code paths for this release."
      ]
    },
    "pr-186": {
      title: "Create robots.txt",
      summary: "Improved create robots.txt.",
      changes: [
        "Updated the related Infra code paths for this release."
      ]
    },
    "pr-185": {
      title: "Spring boot migrate 3.0 -> 3.2",
      summary: "Updated spring boot migrate 3.0 -> 3.2.",
      changes: [
        "Updated the related UI, Infra code paths for this release."
      ]
    },
    "pr-184": {
      title: "Schedule end-datetime UX improved",
      summary: "In case End date-time was set automatically, if the user change Start date-time end date-time also follows it.",
      changes: [
        "Updated the related Calendar, Schedule, UI code paths for this release."
      ]
    },
    "pr-183": {
      title: "DutyType position bug",
      summary: "When get the max position not use dutyTypes size anymore but do find the max value.",
      changes: [
        "Updated the related Team code paths for this release."
      ]
    },
    "pr-182": {
      title: "Duty type rearrangement",
      summary: "Added duty type rearrangement.",
      changes: [
        "Updated the related Team, Admin code paths for this release."
      ]
    },
    "pr-180": {
      title: "Schedule position swap bug",
      summary: "Can not rearrange tagged schedules close #175.",
      changes: [
        "Updated the related Schedule code paths for this release."
      ]
    },
    "pr-179": {
      title: "Remove `close` button on schedule detail modal",
      summary: "It was making people get confused when add schedule.",
      changes: [
        "Updated the related Schedule, UI code paths for this release."
      ]
    },
    "pr-178": {
      title: "#style: scroll to bottom when add new schedule",
      summary: "Added #style: scroll to bottom when add new schedule.",
      changes: [
        "Updated the related Schedule, UI code paths for this release."
      ]
    },
    "pr-177": {
      title: "Kakao SSO Login / sign up",
      summary: "Added kakao SSO Login / sign up.",
      changes: [
        "Updated the related Auth, Security, Schedule, Friends, UI, Infra code paths for this release."
      ]
    },
    "pr-176": {
      title: "Load friends async bug resolved",
      summary: "Fixed load friends async bug resolved.",
      changes: [
        "Updated the related Friends code paths for this release."
      ]
    },
    "pr-174": {
      title: "Tag design adjusted",
      summary: "Improved tag design adjusted.",
      changes: [
        "Updated the related Schedule, UI code paths for this release."
      ]
    },
    "pr-173": {
      title: "Better calendar design",
      summary: "White border was useless when OFF color was white.",
      changes: [
        "So, all the borders are black from now on."
      ]
    },
    "pr-171": {
      title: "Implement schedule visibility",
      summary: "Added implement schedule visibility.",
      changes: [
        "Updated the related Schedule, Friends code paths for this release."
      ]
    },
    "pr-170": {
      title: "Refactor calendar layout with 'row-7' class for consistent width",
      summary: "Improved refactor calendar layout with 'row-7' class for consistent width.",
      changes: [
        "Updated the related Calendar, UI code paths for this release."
      ]
    },
    "pr-169": {
      title: "Refresh token serialize error resolved",
      summary: "Hardened refresh token serialize error resolved.",
      changes: [
        "Updated the related Auth, Security code paths for this release."
      ]
    },
    "pr-168": {
      title: "Guest can retrieve public calendar",
      summary: "Improved guest can retrieve public calendar.",
      changes: [
        "Updated the related Calendar, Schedule, Friends, UI code paths for this release."
      ]
    },
    "pr-167": {
      title: "Visibility setting for calendar itself",
      summary: "Improved visibility setting for calendar itself.",
      changes: [
        "Updated the related Auth, Security, Calendar, Schedule, Team, Friends code paths for this release."
      ]
    },
    "pr-165": {
      title: "Enhance performance by caching",
      summary: "Fixed enhance performance by caching.",
      changes: [
        "Updated the related Calendar, UI code paths for this release."
      ]
    },
    "pr-164": {
      title: "Remove gloss on safari select element",
      summary: "Remove gloss on safari select element.",
      changes: [
        "Updated the related UI code paths for this release."
      ]
    },
    "pr-163": {
      title: "Tag friends on schedule",
      summary: "Improved tag friends on schedule.",
      changes: [
        "Updated the related Schedule, Team, Friends, UI, Infra code paths for this release."
      ]
    },
    "pr-162": {
      title: "Schedule at 00:01 not showing start time",
      summary: "00:01 - 00:01 should show start time.",
      changes: [
        "Also 00:00 - 00:01 should show endtime."
      ]
    },
    "pr-161": {
      title: "Assign member a department / remove",
      summary: "Transaction bug resolved.",
      changes: [
        "Updated the related Team, Admin, UI code paths for this release."
      ]
    },
    "pr-158": {
      title: "Remove sequence column from D-Day",
      summary: "It's troublesome to sort d-day.",
      changes: [
        "Just let it sorted by its day."
      ]
    },
    "pr-153": {
      title: "Friendship",
      summary: "Improved friendship.",
      changes: [
        "Updated the related Calendar, Team, Friends, Admin, UI, Infra code paths for this release."
      ]
    },
    "pr-149": {
      title: "Slack notification when the application is ready & closed",
      summary: "Added slack notification when the application is ready & closed.",
      changes: [
        "Updated the related Notifications code paths for this release."
      ]
    },
    "pr-148": {
      title: "Add `today` button on month-control",
      summary: "Add `today` button on month-control.",
      changes: [
        "Updated the related Calendar, UI code paths for this release."
      ]
    },
    "pr-147": {
      title: "Add index on flyway",
      summary: "Add index on flyway.",
      changes: [
        "Updated the related Infra code paths for this release."
      ]
    },
    "pr-146": {
      title: "#flyway",
      summary: "Updated #flyway.",
      changes: [
        "Updated the related UI, Infra code paths for this release."
      ]
    },
    "pr-144": {
      title: "Bug when update manager in department",
      summary: "Fixed bug when update manager in department.",
      changes: [
        "Updated the related Calendar, Team, UI code paths for this release."
      ]
    },
    "pr-143": {
      title: "Enhance calendar design",
      summary: "Improved enhance calendar design.",
      changes: [
        "Updated the related Auth, Calendar, UI code paths for this release."
      ]
    },
    "pr-142": {
      title: "Remove duplicate filter application due to {'@'}Component annotation",
      summary: "Remove duplicate filter application due to {'@'}Component annotation.",
      changes: [
        "Updated the related Auth, Security, Schedule, Docs code paths for this release."
      ]
    },
    "pr-141": {
      title: "Cache static resources",
      summary: "Improved cache static resources.",
      changes: [
        "Updated the related Auth, UI, Docs code paths for this release."
      ]
    },
    "pr-140": {
      title: "Change password",
      summary: "Hardened change password.",
      changes: [
        "Updated the related Auth, Security, Calendar, Admin, Dashboard, UI code paths for this release."
      ]
    },
    "pr-139": {
      title: "Not use public CDN for libraries anymore",
      summary: "Updated not use public CDN for libraries anymore.",
      changes: [
        "Updated the related Auth, Calendar, Schedule, Todo, Friends, Notifications code paths for this release."
      ]
    },
    "pr-137": {
      title: "Fix css side effect and print schedule content properly",
      summary: "Now schedule content shows properly when it has multiple lines.",
      changes: [
        "Css side effect fixed."
      ]
    },
    "pr-136": {
      title: "Make validators work",
      summary: "Validate parameters from server.",
      changes: [
        "Validate input lengths limits in web."
      ]
    },
    "pr-135": {
      title: "Add thread-safe synchronization to prevent duplicate holiday",
      summary: "Implement ReentrantLock in loadAndSaveHolidaysFromAPI to manage concurrency.",
      changes: [
        "Ensure thread-safe access to holidayMap to avoid duplicate API calls for the same year.",
        "Add checks to prevent redundant API requests and database operations if data already exists."
      ]
    },
    "pr-131": {
      title: "Over year schedule bug fix",
      summary: "When Dec calendar was retrieved, it was considering next JAN as older month, so fixed.",
      changes: [
        "Updated the related Calendar, Schedule code paths for this release."
      ]
    },
    "pr-130": {
      title: "Title length limit (30) in D-Day feature",
      summary: "Fixed title length limit (30) in D-Day feature.",
      changes: [
        "Updated the related UI code paths for this release."
      ]
    },
    "pr-129": {
      title: "Fix index bug in previewing next month's holiday",
      summary: "Correct day calculation in CalendarView to accurately preview days of the next month in the current month's view.",
      changes: [
        "Add test method for December 2023."
      ]
    },
    "pr-127": {
      title: "Not include key file in class-path",
      summary: "Assign it as text instead and put in on file path.",
      changes: [
        "Updated the related Attachments, Infra code paths for this release."
      ]
    },
    "pr-126": {
      title: "Add D-Day on calendar when included",
      summary: "Add D-Day on calendar when included.",
      changes: [
        "Updated the related Calendar code paths for this release."
      ]
    },
    "pr-124": {
      title: "Only logged-in member can view other's duties.",
      summary: "There is a temporary solution until the friend feature is implemented.",
      changes: [
        "Updated the related Auth, Security, Friends code paths for this release."
      ]
    },
    "pr-123": {
      title: "Schedule range bug fixed",
      summary: "Fixed schedule range bug fixed.",
      changes: [
        "Updated the related Schedule code paths for this release."
      ]
    },
    "pr-122": {
      title: "Schedule CRUD UX enhance",
      summary: "Added schedule CRUD UX enhance.",
      changes: [
        "Updated the related Schedule, UI code paths for this release."
      ]
    },
    "pr-121": {
      title: "DDNS instead of using direct ip address",
      summary: "Updated dDNS instead of using direct ip address.",
      changes: [
        "Updated the related Infra code paths for this release."
      ]
    },
    "pr-120": {
      title: "Add dashed border top to holiday (like schedule)",
      summary: "Add dashed border top to holiday (like schedule).",
      changes: [
        "Updated the related Calendar, Schedule, UI code paths for this release."
      ]
    },
    "pr-119": {
      title: "Some style enhancement",
      summary: "If DAY have any schedule, its' background become darker.",
      changes: [
        "Color of public day (but not holiday) color is not red anymore."
      ]
    },
    "pr-118": {
      title: "Added waitMe loader for D-Day CURD calls in Vue app",
      summary: "Added waitMe loader for D-Day CURD calls in Vue app.",
      changes: [
        "Updated the related Maintenance code paths for this release."
      ]
    },
    "pr-117": {
      title: "While editing schedule, hides `add schedule` button",
      summary: "Fixed while editing schedule, hides `add schedule` button.",
      changes: [
        "Updated the related Schedule, UI code paths for this release."
      ]
    },
    "pr-116": {
      title: "Fix bug & add footer",
      summary: "Fix bug & add footer.",
      changes: [
        "Updated the related UI code paths for this release."
      ]
    },
    "pr-114": {
      title: "Holiday info",
      summary: "Improved holiday info.",
      changes: [
        "Updated the related Security, Calendar, Schedule, Notifications, UI, Infra code paths for this release."
      ]
    },
    "pr-113": {
      title: "Improve UI clarity for mobile",
      summary: "Improve UI clarity for mobile.",
      changes: [
        "Updated the related Team, Admin, UI code paths for this release."
      ]
    },
    "pr-111": {
      title: "Improve UI clarity for schedule creation process",
      summary: "Improve UI clarity for schedule creation process.",
      changes: [
        "Updated the related Schedule, Admin, UI, Infra code paths for this release."
      ]
    },
    "pr-110": {
      title: "Separate AdminAuthFilter and ActuatorFilter",
      summary: "Hardened separate AdminAuthFilter and ActuatorFilter.",
      changes: [
        "Updated the related Auth, Security, Admin, Docs code paths for this release."
      ]
    },
    "pr-109": {
      title: "Prometheus Monitoring",
      summary: "Updated prometheus Monitoring.",
      changes: [
        "Updated the related Auth, Security, Admin, UI, Infra, Docs code paths for this release."
      ]
    },
    "pr-108": {
      title: "Mobile bigger menu",
      summary: "Improved mobile bigger menu.",
      changes: [
        "Updated the related UI code paths for this release."
      ]
    },
    "pr-107": {
      title: "Menu layout UI enhance",
      summary: "Improved menu layout UI enhance.",
      changes: [
        "Updated the related Auth, Security, Admin, Attachments, UI code paths for this release."
      ]
    },
    "pr-106": {
      title: "SSL certificate update",
      summary: "Hardened sSL certificate update.",
      changes: [
        "Updated the related Security, Calendar, Infra code paths for this release."
      ]
    },
    "pr-105": {
      title: "Exclude /.well-known from redirect HTTPS",
      summary: "Hardened exclude /.well-known from redirect HTTPS.",
      changes: [
        "Updated the related Security code paths for this release."
      ]
    },
    "pr-104": {
      title: "Use secret submodule for secret files instead of base64 data",
      summary: "Updated use secret submodule for secret files instead of base64 data.",
      changes: [
        "Updated the related Attachments, Infra code paths for this release."
      ]
    },
    "pr-103": {
      title: "Slack notification minimum interval is configured by properties…",
      summary: "Added slack notification minimum interval is configured by properties….",
      changes: [
        "Updated the related Notifications code paths for this release."
      ]
    },
    "pr-102": {
      title: "JWT Interceptor -> filter refactored",
      summary: "Hardened jWT Interceptor -> filter refactored.",
      changes: [
        "Updated the related Auth, Security, Schedule, Admin, UI, Infra code paths for this release."
      ]
    },
    "pr-100": {
      title: "Schedule position order change feature",
      summary: "Improved schedule position order change feature.",
      changes: [
        "Updated the related Schedule, Infra, Docs code paths for this release."
      ]
    },
    "pr-99": {
      title: "Remove duty-edit page. Hooray !",
      summary: "Duty.html handle it async.",
      changes: [
        "Updated the related UI code paths for this release."
      ]
    },
    "pr-98": {
      title: "Small design improvement, UX enhancement, bug fix",
      summary: "Date compare bug fixed.",
      changes: [
        "12:00 PM bug fixed.",
        "Can update department OFF color.",
        "Can assign department manager [null]."
      ]
    },
    "pr-97": {
      title: "Hotfix some minor bugs and style",
      summary: "Fixed hotfix some minor bugs and style.",
      changes: [
        "Updated the related Notifications, Admin, UI code paths for this release."
      ]
    },
    "pr-95": {
      title: "Slack message only being sent maximum once a ten seconds",
      summary: "Fixed slack message only being sent maximum once a ten seconds.",
      changes: [
        "Updated the related Schedule, Notifications code paths for this release."
      ]
    },
    "pr-94": {
      title: "Feature: Schedule",
      summary: "Must run sql to migrate memo -> schedule.",
      changes: [
        "Memo column could be eliminated.",
        "``sql INSERT INTO schedule (id, member_id, content, start_date_time, end_date_time, position) SELECT UUID(), d.member_id, TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(d.memo, '\\n', numbers.n), '\\n', -1)), TIMESTAMP(CONCAT_WS('-', d.duty_year, d.duty_month, d.duty_day)), TIMESTAMP(CONCAT_WS('-', d.duty_year, d.duty_month, d.duty_day)), numbers.n."
      ]
    },
    "pr-93": {
      title: "Slide refresh token cookie validation",
      summary: "Validation was extending when login succeed but token cookie was not, which means \"meaningless\" so updated it.",
      changes: [
        "Updated the related Auth, Security, Calendar code paths for this release."
      ]
    },
    "pr-91": {
      title: "D-Day calculator added",
      summary: "So if select d-Day event, it will show the count on current calendar close #90.",
      changes: [
        "Updated the related Calendar, UI code paths for this release."
      ]
    },
    "pr-89": {
      title: "Order members on index page",
      summary: "Fixed order members on index page.",
      changes: [
        "Updated the related Maintenance code paths for this release."
      ]
    },
    "pr-88": {
      title: "Larger modal for member search on admin",
      summary: "Fixed larger modal for member search on admin.",
      changes: [
        "Updated the related Team, Admin, UI code paths for this release."
      ]
    },
    "pr-87": {
      title: "Department manager system",
      summary: "Added department manager system.",
      changes: [
        "Updated the related Calendar, Team, Admin, UI code paths for this release."
      ]
    },
    "pr-86": {
      title: "Edit page memo UX enhanced",
      summary: "Memo pre-line now working on edit as well.",
      changes: [
        "Edit page have duty-type labels.",
        "Smaller buttons for changing duty-type."
      ]
    },
    "pr-84": {
      title: "Admin department management",
      summary: "Improved admin department management.",
      changes: [
        "Updated the related Auth, Security, Team, Admin, Dashboard, UI code paths for this release."
      ]
    },
    "pr-82": {
      title: "Favicon for all environments",
      summary: "Updated favicon for all environments.",
      changes: [
        "Updated the related Friends, UI, Infra code paths for this release."
      ]
    },
    "pr-81": {
      title: "Apple-touch-icon become absolute path.",
      summary: "Fixed apple-touch-icon become absolute path.",
      changes: [
        "Updated the related UI code paths for this release."
      ]
    },
    "pr-80": {
      title: "Update favicon",
      summary: "Update favicon.",
      changes: [
        "Updated the related Calendar, UI, Infra code paths for this release."
      ]
    },
    "pr-78": {
      title: "CI/CD and minor updates",
      summary: "Readability enhanced for \"today\", SAT, SUN.",
      changes: [
        "P6spy stack trace enabled.",
        "CI/CD job added."
      ]
    },
    "pr-72": {
      title: "Revoke expired refresh tokens",
      summary: "Also ssl certificate is renewed.",
      changes: [
        "Updated the related Auth, Security, Admin, Infra code paths for this release."
      ]
    },
    "pr-71": {
      title: "Refactored test codes",
      summary: "Use datainit class so doesn't need to init in every single test.",
      changes: [
        "Use {'@'}Transactional positively for rollback tests."
      ]
    },
    "pr-70": {
      title: "My login management page enhancement",
      summary: "Order by last active.",
      changes: [
        "Last active display changed ( from-now using day.js).",
        "Jwt validate second 3600s -> 1800s."
      ]
    },
    "pr-68": {
      title: "My login management",
      summary: "Added my login management.",
      changes: [
        "Updated the related Auth, Security, UI code paths for this release."
      ]
    },
    "pr-67": {
      title: "Admin page added",
      summary: "P6spy boot3.0 issue resolved.",
      changes: [
        "All active login info monitoring page."
      ]
    },
    "pr-65": {
      title: "Simple admin page",
      summary: "Simple admin page to check Refresh Token info.",
      changes: [
        "Updated the related Auth, Security, Admin code paths for this release."
      ]
    },
    "pr-64": {
      title: "Refresh token records remote info",
      summary: "Hardened refresh token records remote info.",
      changes: [
        "Updated the related Auth, Security, UI, Infra code paths for this release."
      ]
    },
    "pr-63": {
      title: "D + days calculate fix",
      summary: "The day after D-Day should be Day 2 (D+2).",
      changes: [
        "Updated the related Maintenance code paths for this release."
      ]
    },
    "pr-62": {
      title: "D-Day UX improvement",
      summary: "DDay update slack notification.",
      changes: [
        "Wait me when rearrange dDay orders.",
        "Dday edit -> better experience."
      ]
    },
    "pr-57": {
      title: "D-Day calculation was not correct",
      summary: "Now it's calculated from server.",
      changes: [
        "Updated the related Maintenance code paths for this release."
      ]
    },
    "pr-56": {
      title: "D-Day Counter",
      summary: "RESTAPI and also view page for D-Day counter.",
      changes: [
        "Updated the related Auth, Security, UI code paths for this release."
      ]
    },
    "pr-53": {
      title: "Duty edit page off+memo color bug fixed",
      summary: "If there's memo on off day, background color was not properly presented.",
      changes: [
        "Now it's ok."
      ]
    },
    "pr-52": {
      title: "Style",
      summary: "Month indicator centre.",
      changes: [
        "Ios Safari issue."
      ]
    },
    "pr-49": {
      title: "Highlight today on edit page, preview next month blocks bug fix",
      summary: "Fixed highlight today on edit page, preview next month blocks bug fix.",
      changes: [
        "Updated the related Calendar, UI code paths for this release."
      ]
    },
    "pr-45": {
      title: "Calendar Explorer",
      summary: "#41.",
      changes: [
        "Updated the related Calendar, UI code paths for this release."
      ]
    },
    "pr-44": {
      title: "Calendar explorer",
      summary: "Improved calendar explorer.",
      changes: [
        "Updated the related Auth, Security, Calendar, Attachments, UI code paths for this release."
      ]
    },
    "pr-43": {
      title: "Edit, back button text edited",
      summary: "Updated edit, back button text edited.",
      changes: [
        "Updated the related UI code paths for this release."
      ]
    },
    "pr-42": {
      title: "Login page - mobile UI",
      summary: "Responsive web ui.",
      changes: [
        "Updated the related Auth, Security, Attachments, UI code paths for this release."
      ]
    },
    "pr-39": {
      title: "Authentication",
      summary: "Hardened authentication.",
      changes: [
        "Updated the related Auth, Security, Calendar, Team, Notifications, UI code paths for this release."
      ]
    },
    "pr-35": {
      title: "Spring Boot 2.7.4 -> 3.0.0 migration",
      summary: "Improved spring Boot 2.7.4 -> 3.0.0 migration.",
      changes: [
        "Updated the related Team, Notifications, UI, Infra code paths for this release."
      ]
    },
    "pr-33": {
      title: "Password Encoder changed, csrf disabled",
      summary: "Hardened password Encoder changed, csrf disabled.",
      changes: [
        "Updated the related Auth, Security, UI, Infra code paths for this release."
      ]
    },
    "pr-32": {
      title: "HTTPS SSL Secure",
      summary: "Hardened hTTPS SSL Secure.",
      changes: [
        "Updated the related Security, UI, Infra code paths for this release."
      ]
    },
    "pr-31": {
      title: "Read & update optimization",
      summary: "Update latency improved: 600ms -> 100ms.",
      changes: [
        "Updated the related Calendar, Team, Notifications, UI, Infra code paths for this release."
      ]
    },
    "pr-30": {
      title: "Request not with domain address are ignored",
      summary: "Because of too many random requests.",
      changes: [
        "Updated the related Maintenance code paths for this release."
      ]
    },
    "pr-26": {
      title: "Send slack notification async",
      summary: "Improved send slack notification async.",
      changes: [
        "Updated the related Notifications code paths for this release."
      ]
    },
    "pr-24": {
      title: "Input password when move to edit page #10",
      summary: "#10.",
      changes: [
        "Updated the related Auth, Security, UI code paths for this release."
      ]
    },
    "pr-21": {
      title: "Duty edit page UX improvement",
      summary: "Improved duty edit page UX improvement.",
      changes: [
        "Updated the related UI code paths for this release."
      ]
    },
    "pr-19": {
      title: "Handle method not supported Exception",
      summary: "Fixed handle method not supported Exception.",
      changes: [
        "Updated the related Notifications code paths for this release."
      ]
    },
    "pr-17": {
      title: "Added arrow for edit page",
      summary: "Removed repeated code.",
      changes: [
        "Hided scrollbar which was irritating.",
        "Added arrow for edit duty page as well."
      ]
    },
    "pr-15": {
      title: "Slack webhook for exceptions",
      summary: "Fixed slack webhook for exceptions.",
      changes: [
        "Updated the related Calendar, Notifications, UI, Infra code paths for this release."
      ]
    },
    "pr-13": {
      title: "Responsive web design for mobile",
      summary: "Mobile ui.",
      changes: [
        "Updated the related UI code paths for this release."
      ]
    },
    "pr-11": {
      title: "Duty edit UI improved",
      summary: "Duty change button UI improved.",
      changes: [
        "Memo change UI improved."
      ]
    },
    "pr-8": {
      title: "Added home button",
      summary: "Added home button.",
      changes: [
        "Updated the related Dashboard, UI code paths for this release."
      ]
    },
    "pr-7": {
      title: "Memo function improved",
      summary: "Multiple line memo supported.",
      changes: [
        "Original memo will be show up when edit it.",
        "Duty readability improved."
      ]
    }
  }
} satisfies ReleaseNotesMessages<ReleaseNoteId>
