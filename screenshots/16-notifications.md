# Notifications Feature - iOS Implementation Status

## Screenshot Analysis

The screenshot shows a notifications screen with the following features:
- Header with "알림" (Notifications) title
- Info text: "알림은 30일간 보관됩니다" (Notifications are stored for 30 days)
- "Mark all as read" button (checkmark icon)
- "Delete read notifications" button (trash icon)
- Notification list showing:
  - Schedule tag notifications ("이동헌님의 [태그 ○] 일정에 태그되었습니다", "이동헌님이 스케줄에 태그했습니다")
  - Friend request notifications ("동은님이 친구 요청을 보냈습니다")
  - Profile avatars
  - Notification content/subtitle (e.g., "태그 ○")
  - Date format: relative date + absolute date (e.g., "5일 전 (2026.01.08 16:25)")
- Bottom tab navigation: 홈, 내 달력, 할일, 내 팀, 설정

## iOS Implementation Status

### Implemented Features

| Feature | Status | File |
|---------|--------|------|
| Notification list view | Implemented | `NotificationListView.swift` |
| Notification data model | Implemented | `Notification.swift` |
| Notification view model | Implemented | `NotificationViewModel.swift` |
| Individual notification row | Implemented | `NotificationRow.swift` |
| Notification badge component | Implemented | `NotificationBadge.swift` |
| Mark all as read | Implemented | Menu option in `NotificationListView` |
| Delete read notifications | Implemented | Menu option in `NotificationListView` |
| Individual delete (swipe) | Implemented | Swipe action in list |
| Individual mark as read (swipe) | Implemented | Swipe action in list |
| Pagination (infinite scroll) | Implemented | `hasMore` + `loadNotifications()` |
| Pull to refresh | Implemented | `.refreshable` modifier |
| API endpoints | Implemented | `Endpoint.swift` |
| Access via bell icon | Implemented | `DashboardView` toolbar button |
| Profile avatar display | Implemented | `ProfileAvatar` component |
| Notification type badges | Implemented | Badge in `NotificationRow` |
| Read/unread state indicator | Implemented | Blue dot + background color |

### Missing/Different Features

| Feature | Web | iOS | Priority |
|---------|-----|-----|----------|
| Retention info text | "알림은 30일간 보관됩니다" displayed below header | Not displayed | Low |
| Date format | Relative + absolute date (e.g., "5일 전 (2026.01.08 16:25)") | Relative date only (e.g., "5일 전") | Medium |
| Unread notification badge count | Bell icon shows unread count | Bell icon without count badge | High |

## Required Changes

### 1. Add Unread Notification Badge (High Priority)

The `NotificationBellButton` component exists but is not used in `DashboardView`. The dashboard uses a plain bell button without the unread count badge.

**Current code in DashboardView.swift:**
```swift
Button(action: { showNotifications = true }) {
    Image(systemName: "bell")
        .foregroundColor(...)
}
```

**Should use:**
```swift
NotificationBellButton(action: { showNotifications = true })
```

Or integrate the unread count badge directly.

### 2. Update Date Format (Medium Priority)

Update `NotificationRow.swift` to show both relative and absolute dates.

**Current format:** "5일 전"
**Expected format:** "5일 전 (2026.01.08 16:25)"

Update the `formatDate` and `relativeDate` functions in `NotificationRow.swift`.

### 3. Add Retention Info Text (Low Priority)

Add "알림은 30일간 보관됩니다" info text below the navigation title in `NotificationListView.swift`.

## Files to Modify

1. `/ios/Dutypark/Features/Dashboard/DashboardView.swift` - Use NotificationBellButton or add badge
2. `/ios/Dutypark/Features/Notification/NotificationRow.swift` - Update date format
3. `/ios/Dutypark/Features/Notification/NotificationListView.swift` - Add retention info text
