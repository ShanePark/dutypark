# Dutypark Frontend

Vue 3 SPA for Dutypark duty management application.

## Tech Stack

| Category | Technology |
|----------|------------|
| Framework | Vue 3.5 (Composition API) |
| Build | Vite 7.2 |
| Language | TypeScript 5.9 |
| State | Pinia 3 |
| Routing | Vue Router 4 |
| Styling | Tailwind CSS 4 |
| HTTP | Axios |
| Icons | Lucide Vue |

## Quick Start

```bash
# Install dependencies
npm install

# Development server (http://localhost:5173)
npm run dev

# Type check
npm run type-check

# Production build
npm run build

# Preview production build
npm run preview
```

## Project Structure

```
src/
├── api/                 # API client modules
│   ├── client.ts        # Axios instance, interceptors, token manager
│   ├── auth.ts          # Authentication (Bearer token, OAuth)
│   ├── admin.ts         # Admin API (/admin/api)
│   ├── dashboard.ts     # Dashboard aggregation
│   ├── duty.ts          # Duty calendar CRUD
│   ├── schedule.ts      # Schedule CRUD, tagging, search
│   ├── todo.ts          # Todo CRUD, ordering
│   ├── member.ts        # Member, friends, D-Day, refresh tokens
│   ├── team.ts          # Team management, duty types
│   └── attachment.ts    # File upload sessions, utilities
├── components/
│   ├── common/          # Reusable components
│   │   ├── FileUploader.vue      # Uppy-based file upload
│   │   ├── AttachmentGrid.vue    # Attachment display grid
│   │   ├── ImageViewer.vue       # Full-screen image carousel
│   │   └── YearMonthPicker.vue   # Year/month selector
│   ├── duty/            # Domain modals
│   │   ├── DayDetailModal.vue    # Main day edit modal
│   │   ├── TodoAddModal.vue      # Todo creation
│   │   ├── TodoDetailModal.vue   # Todo view/edit
│   │   ├── TodoOverviewModal.vue # Todo list with drag-drop
│   │   ├── DDayModal.vue         # D-Day CRUD
│   │   ├── OtherDutiesModal.vue  # Friend selection
│   │   ├── ScheduleDetailModal.vue
│   │   └── SearchResultModal.vue
│   └── layout/
│       ├── AppLayout.vue         # Main layout wrapper
│       ├── AppHeader.vue         # Top navigation
│       └── AppFooter.vue         # Bottom tab bar
├── composables/
│   ├── useSwal.ts       # SweetAlert2 wrapper
│   └── useKakao.ts      # Kakao OAuth integration
├── stores/
│   └── auth.ts          # Authentication state (Pinia)
├── views/               # Route pages
│   ├── auth/            # Login, OAuth callback, SSO
│   ├── dashboard/       # DashboardView
│   ├── duty/            # DutyView (calendar)
│   ├── member/          # MemberView (settings)
│   ├── team/            # TeamView, TeamManageView
│   └── admin/           # Admin dashboard, team list
├── types/
│   └── index.ts         # All TypeScript interfaces
├── router/
│   └── index.ts         # Route definitions & guards
├── main.ts              # App bootstrap
├── App.vue              # Root component
└── style.css            # Tailwind + design tokens
```

## Architecture

### API Client (`src/api/client.ts`)

Central Axios instance with:
- **Base URL:** `/api` (proxied to backend in dev)
- **Token Management:** `tokenManager` for localStorage JWT handling
- **Request Interceptor:** Adds `Authorization: Bearer {token}` header
- **Response Interceptor:** Auto-refresh on 401 with request queuing

```typescript
import apiClient from '@/api/client'

// All API modules use this pattern
export const exampleApi = {
  getItems: () => apiClient.get<ItemDto[]>('/items'),
  createItem: (data) => apiClient.post<ItemDto>('/items', data),
}
```

### Authentication Flow

1. Login via `authStore.login()` → POST `/auth/token`
2. Tokens stored in `localStorage` via `tokenManager`
3. All requests include `Authorization: Bearer {token}`
4. On 401 → auto-refresh via `/auth/refresh` → retry original request
5. Router guards check `authStore.isLoggedIn` / `authStore.isAdmin`

### State Management

**Pinia Store (`useAuthStore`):**
- `user: LoginMember | null` - Current user
- `isLoggedIn: boolean` - Derived from user presence
- `isAdmin: boolean` - Admin role check
- Actions: `initialize()`, `login()`, `logout()`, `checkAuth()`

**Composables:**
- `useSwal()` - Toast notifications and confirmations
- `useKakao()` - Kakao OAuth SDK wrapper

## Routes

| Path | Component | Auth | Description |
|------|-----------|------|-------------|
| `/` | DashboardView | Optional | Home dashboard |
| `/auth/login` | LoginView | Guest only | Login page |
| `/auth/oauth-callback` | OAuthCallbackView | - | OAuth redirect handler |
| `/auth/sso-signup` | SsoSignupView | - | SSO signup form |
| `/auth/sso-congrats` | SsoCongratsView | Required | Post-signup page |
| `/duty/:id` | DutyView | Optional | Duty calendar |
| `/member` | MemberView | Required | Profile settings |
| `/team` | TeamView | Required | Team calendar |
| `/team/manage/:teamId` | TeamManageView | Required | Team admin |
| `/admin` | AdminDashboardView | Admin | Admin panel |
| `/admin/teams` | AdminTeamListView | Admin | Team management |

## Key Components

### FileUploader

Uppy-based file upload with drag-drop support.

```vue
<FileUploader
  context-type="SCHEDULE"
  :target-context-id="scheduleId"
  :existing-attachments="attachments"
  @update:attachments="onAttachmentsChange"
  @session-created="onSessionCreated"
/>
```

Props:
- `contextType`: `'SCHEDULE' | 'PROFILE' | 'TEAM' | 'TODO'`
- `targetContextId`: Existing entity ID (optional for new entities)
- `existingAttachments`: Pre-loaded attachments
- `disabled`: Disable upload

Emits:
- `update:attachments`: Attachment list changed
- `session-created`: Upload session ID created
- `upload-complete`: All uploads finished

### DayDetailModal

Main modal for viewing/editing day's data.

Features:
- Schedule CRUD with SortableJS drag-drop reorder
- File attachments per schedule
- Friend tagging system
- Duty type quick-select buttons
- Todo integration

### ImageViewer

Full-screen image carousel with:
- Touch swipe navigation
- Keyboard arrow/escape support
- Authenticated image loading
- Download functionality

## API Modules

| Module | Base Path | Key Functions |
|--------|-----------|---------------|
| `auth` | `/auth` | `loginWithToken`, `refresh`, `getStatus`, `logout` |
| `dashboard` | `/dashboard` | `getMyDashboard`, `getFriendsDashboard` |
| `duty` | `/duty` | `getDuties`, `updateDuty`, `batchUpdateDuty` |
| `schedule` | `/schedules` | `getSchedules`, `saveSchedule`, `tagFriend`, `reorderSchedulePositions` |
| `todo` | `/todos` | `getActiveTodos`, `createTodo`, `completeTodo`, `updatePositions` |
| `member` | `/members`, `/friends`, `/dday` | User profile, friends, D-Day events |
| `team` | `/teams` | Team info, schedules, duty types, member management |
| `attachment` | `/attachments` | `createSession`, `listAttachments`, `reorderAttachments` |
| `admin` | `/admin/api` | `getAllMembers`, `getAllRefreshTokens`, `getTeams` |

## TypeScript Types

All types defined in `src/types/index.ts`:

**Core Entities:**
- `LoginMember`, `Member`, `MemberDto`
- `Team`, `TeamDto`, `SimpleTeam`
- `Duty`, `DutyType`, `DutyCalendarDay`
- `Schedule`, `ScheduleTag`
- `Todo`, `TodoStatus`
- `DDay`, `DDayDto`
- `Friend`, `FriendRequest`

**API Types:**
- `TokenResponse` - JWT tokens
- `Page<T>` - Pagination wrapper
- `AttachmentDto`, `NormalizedAttachment`
- `CalendarVisibility` - `'PUBLIC' | 'FRIENDS' | 'FAMILY' | 'PRIVATE'`

## Styling

Tailwind CSS 4 with custom design tokens in `style.css`:

**Colors:**
- `primary`, `secondary`, `success`, `danger`, `warning`
- `bg-*` variants for backgrounds
- `text-*` for typography
- `sunday`, `saturday`, `holiday` for calendar

**Component Classes:**
- `.btn-*` - Button variants
- `.card`, `.card-body` - Card containers
- `.form-control`, `.form-label` - Form elements
- `.day-grid*` - Calendar day cells
- `.sortable-*` - Drag-drop states
- `.attachment-*` - File display

## Development

### Vite Proxy

Dev server proxies to backend:
```
/api/*       → http://localhost:8080
/admin/api/* → http://localhost:8080
/logout      → http://localhost:8080
```

### Path Alias

`@/` maps to `src/`:
```typescript
import { useAuthStore } from '@/stores/auth'
import type { Schedule } from '@/types'
```

### Adding New API Module

1. Create `src/api/newModule.ts`:
```typescript
import apiClient from './client'
import type { NewDto } from '@/types'

export const newModuleApi = {
  getItems: () => apiClient.get<NewDto[]>('/new-endpoint'),
  createItem: (data: CreateDto) => apiClient.post<NewDto>('/new-endpoint', data),
}
```

2. Add types to `src/types/index.ts`
3. Use in components via import

### Adding New Route

1. Create view component in `src/views/`
2. Add route in `src/router/index.ts`:
```typescript
{
  path: '/new-route',
  name: 'new-route',
  component: () => import('@/views/NewView.vue'),
  meta: { requiresAuth: true }
}
```

## External Dependencies

| Library | Purpose |
|---------|---------|
| Uppy | File upload with progress |
| SortableJS | Drag-drop reordering |
| SweetAlert2 | Notifications & confirmations |
| dayjs | Date formatting |
| Pickr | Color picker |
| Kakao SDK | OAuth SSO (loaded via CDN) |

## Build Output

Production build creates optimized bundle in `dist/`:
- Code-split chunks per route (lazy loading)
- CSS purged of unused classes
- Source maps for debugging
