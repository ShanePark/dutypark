# Hamburger Menu Implementation Status (iOS App)

This document compares the hamburger menu features shown in the screenshot with the iOS app implementation.

## Screenshot Menu Items vs iOS Implementation

| Web App Menu Item | Korean | iOS Implementation Status |
|-------------------|--------|---------------------------|
| Home | 홈 | Implemented (TabView - DashboardView) |
| My Calendar | 내 달력 | Implemented (TabView - DutyView) |
| My Team | 내 팀 | Implemented (TabView - TeamView) |
| Friend Management | 친구 관리 | Implemented (Menu in DashboardView, also FriendsView sheet) |
| Todo | 할일 | Implemented (TabView - TodoBoardView) |
| Notifications | 알림 | Implemented (Bell icon + Menu in DashboardView, NotificationListView) |
| Management | 관리 | Implemented (Settings icon in TeamView for managers only) |
| **Usage Guide** | **이용 안내** | **NOT IMPLEMENTED** |
| Settings | 설정 | Implemented (TabView - SettingsView) |
| Logout | 로그아웃 | Implemented (Menu in DashboardView + SettingsView) |

## Missing Features

### 1. Usage Guide (이용 안내)
- **Priority**: Medium
- **Description**: A help/guide page that provides usage instructions for the app
- **Location in Web App**: Accessible from hamburger menu
- **Required Implementation**:
  - Create `UsageGuideView.swift` in `Features/` directory
  - Add navigation link to the view from DashboardView menu or SettingsView
  - Content should include:
    - App overview and purpose
    - Feature explanations (Duty calendar, Schedule management, Todo, Team features, etc.)
    - FAQ or common questions
    - Contact information or support links

## Notes

- The iOS app uses a bottom TabView instead of a hamburger menu for primary navigation
- Secondary features (Friends, Notifications, D-Day) are accessible via a menu button (3 horizontal lines) in DashboardView
- Team management is accessible via a settings icon in TeamView (only visible to team managers)
