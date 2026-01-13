# Admin Teams View - iOS Implementation Status

## Screenshot Analysis

The screenshot shows the Admin Teams management view with the following features:

### Admin Navigation (Top Section)
4 navigation buttons in a 2x2 grid:
1. **Member Management** (회원 관리) - Navigate to member list and management
2. **Team Management** (팀 관리) - Current active view, navigate to team list
3. **Development** (개발) - Development tools and utilities
4. **API Documentation** (API 문서) - External link to API docs

### Team List Section
- **Header**: Shows "팀 목록" with count "총 0개의 팀이 있습니다"
- **Search Input**: Text field with placeholder "팀 검색..."
- **Search Button**: "검색" button to trigger search
- **Add Button**: Blue "+ 추가" button to create new team

---

## iOS Implementation Status

### Currently Implemented
- `LoginMember` model has `isAdmin` boolean property
- Team management view exists (`TeamManageView.swift`) but for team managers, not system admins

### Missing Features (Not Implemented)

#### 1. Admin Navigation
- [ ] Admin Dashboard view with navigation buttons
- [ ] Navigation to Member Management
- [ ] Navigation to Team Management (admin level)
- [ ] Navigation to Development tools
- [ ] Link to API Documentation

#### 2. Admin Team List View
- [ ] List all teams (paginated)
- [ ] Team search functionality
- [ ] Display team count
- [ ] Team card showing: name, description, member count
- [ ] Click to navigate to team management

#### 3. Create Team Modal/Sheet
- [ ] Team name input (2-20 characters)
- [ ] Team name availability check
- [ ] Team description input (up to 50 characters)
- [ ] Create team API call
- [ ] Navigate to team management after creation

#### 4. Admin API Endpoints (Missing in Endpoint.swift)
- [ ] `GET /admin/api/teams` - List all teams (paginated, searchable)
- [ ] `POST /admin/api/teams` - Create new team
- [ ] `GET /admin/api/teams/name-check` - Check team name availability
- [ ] `GET /admin/api/members` - List all members (paginated, searchable)
- [ ] `GET /admin/api/refresh-tokens` - Get all active refresh tokens
- [ ] `PUT /admin/api/auth/password` - Admin password change for any member

#### 5. Admin Models (Need to be created)
- [ ] `SimpleTeam` - id, name, description, memberCount
- [ ] `AdminMemberDto` - id, name, teamId, tokens, hasProfilePhoto, profilePhotoVersion
- [ ] `TeamNameCheckResult` - OK, TOO_SHORT, TOO_LONG, DUPLICATED
- [ ] `CreateTeamRequest` - name, description

#### 6. Admin Access Control
- [ ] Check `isAdmin` flag before showing admin features
- [ ] Redirect non-admin users away from admin views
- [ ] Add admin section to Settings or separate tab (if admin)

---

## Recommended Implementation Order

1. **API Layer**: Add admin endpoints to `Endpoint.swift`
2. **Models**: Create admin-specific data models
3. **ViewModel**: Create `AdminViewModel.swift` for state management
4. **Views**:
   - `AdminDashboardView.swift` - Main admin navigation
   - `AdminTeamListView.swift` - Team list with search and pagination
   - `CreateTeamSheet.swift` - Modal for creating new teams
5. **Navigation**: Add admin entry point (conditional on `isAdmin`)

---

## Notes

- The entire admin module is missing from the iOS app
- Web frontend has full admin functionality in `AdminDashboardView.vue` and `AdminTeamListView.vue`
- iOS app should check `authManager.user?.isAdmin` before showing admin features
- Consider adding admin section as a separate tab or within Settings view
