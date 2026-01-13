# Admin Dashboard - iOS Implementation Status

## Screenshot Analysis

The web Admin Dashboard (screenshot 17) shows the following features:

### 1. Navigation Menu (4 cards at top)
- **Member Management** (회원 관리) - Currently selected with dark background
- **Team Management** (팀 관리) - Links to team admin page
- **Development** (개발) - Developer tools section
- **API Documentation** (API 문서) - External link to API docs

### 2. Statistics Cards (4 metrics)
- **Total Members** (전체 등록 회원): Shows count of registered members
- **Active Teams** (활성 등록 팀): Shows count of active teams
- **Active Tokens** (유효 활성 토큰): Shows count of valid refresh tokens
- **Today's Logins** (오늘 접속 횟수): Shows today's access count

### 3. Member Management Section
- **Search Bar**: Search members by name or keyword
- **Member List**: Displays member info with:
  - Profile avatar
  - Member name
  - Active session count
  - "Change Password" (비밀번호 변경) button
- **Session Details**: Expandable token/session information per member
- **Pagination**: Navigate through member pages

---

## iOS App Implementation Status

### Currently Implemented
- `LoginMember.isAdmin` field exists in `/ios/Dutypark/Core/Models/Auth.swift` but is not utilized

### Missing Features (Not Implemented)

#### Admin Views
- [ ] `AdminDashboardView.swift` - Main admin dashboard view
- [ ] `AdminTeamListView.swift` - Team management view for admins
- [ ] Admin navigation in `MainTabView` or `SettingsView` (conditional on `isAdmin`)

#### Admin API Endpoints
- [ ] `/admin/api/members` - Get paginated member list with search
- [ ] `/admin/api/refresh-tokens` - Get all refresh tokens system-wide
- [ ] `/admin/api/teams` - Admin team CRUD operations

#### Admin Features
- [ ] Statistics dashboard showing:
  - Total member count
  - Active team count
  - Active token count
  - Today's login count
- [ ] Member search functionality
- [ ] Member list with session information
- [ ] Admin password change for any member (`changePassword` with `memberId` parameter)
- [ ] Session revocation for any member
- [ ] Team management (create/delete teams)

#### Admin ViewModel
- [ ] `AdminViewModel.swift` - Handles admin data fetching and state management

---

## Implementation Priority

1. **High Priority**: Add admin check in app to conditionally show admin menu
2. **Medium Priority**: Implement AdminDashboardView with statistics and member list
3. **Lower Priority**: Team management features (create/delete teams)

## Notes

- The web implementation uses a separate Axios client (`adminClient`) with `/admin/api` base path
- Admin features are protected by `isAdmin` check in the auth store
- Consider whether full admin functionality is needed on mobile or if a subset is sufficient
