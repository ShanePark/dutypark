# Admin Dev Screen - iOS Implementation Status

## Screenshot Analysis (31-admin-dev.png)

The screenshot shows the **Admin Development Playground** page with the following features:

### Admin Navigation Tabs (Top Grid)
1. **Member Management** (회원 관리) - Admin member list and management
2. **Team Management** (팀 관리) - Admin team list and management
3. **Development** (개발) - Currently selected, development playground
4. **API Documentation** (API 문서) - External link to REST docs

### Development Playground Content
5. **Page Header** - "개발 플레이그라운드" with description "컴포넌트를 테스트하고 비교해볼 수 있는 공간입니다."
6. **Example Section** (예제 섹션) - Expandable section for component testing

---

## Missing Features in iOS App

The entire Admin functionality is **NOT implemented** in the iOS app. The following features need to be added:

### 1. Admin Tab/Access Point
- [ ] Add admin access in Settings or a dedicated Admin tab (visible only to admin users)
- [ ] Check `isAdmin` flag from `LoginMember` to show/hide admin features

### 2. Admin Dashboard View (AdminDashboardView)
- [ ] Stats cards (total members, total teams, active tokens, today logins)
- [ ] Member list with search and pagination
- [ ] Per-member session management (view/revoke tokens)
- [ ] Password change functionality for members

### 3. Admin Team List View (AdminTeamListView)
- [ ] List all teams with member counts
- [ ] Team management actions

### 4. Dev Playground View (DevPlaygroundView)
- [ ] Admin navigation grid (same as other admin views)
- [ ] Page header with description
- [ ] Expandable example section for component testing

### 5. API Client Extensions
- [ ] `adminApi` endpoints for:
  - `GET /admin/api/members` - Get members with pagination
  - `GET /admin/api/refresh-tokens` - Get all refresh tokens
  - `DELETE /admin/api/refresh-tokens/{id}` - Revoke specific token
  - `PUT /api/auth/password` (admin variant) - Change member password

---

## Priority

**Low Priority** - Admin/Development tools are typically used by developers and administrators only. Consider implementing these features after core user-facing features are complete.

## Notes

- The `isAdmin` field already exists in `LoginMember` model (`ios/Dutypark/Core/Models/Auth.swift`)
- Admin features should only be visible to users with `isAdmin == true`
- The "API Documentation" link opens external REST docs which may not be practical for iOS app
