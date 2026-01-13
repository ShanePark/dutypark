# 06-search-modal-empty.png - Missing Features

## Screenshot Description
The screenshot shows a schedule search modal ("검색 결과") appearing from the DutyView (calendar view) with:
- Modal title "검색 결과" (Search Results)
- Close button (X) in top right
- Search input field with placeholder "검색어 입력..."
- Blue "검색" (Search) button
- Empty state message "검색어를 입력해주세요."

## Implementation Status

### Implemented
- `ScheduleSearchView` component exists in `/Users/shane/Documents/GitHub/dutypark/ios/Dutypark/Features/Schedule/ScheduleListView.swift` (lines 209-257)
- `SearchBar` reusable component exists
- `searchSchedules` API endpoint exists in `Endpoint.swift`
- `ScheduleViewModel` has search functionality (`searchResults`, `isSearching`, `searchSchedules` method)
- DutyView has a search button that sets `showSearch = true` (lines 114-128)

### Missing
1. **DutyView search button not connected to search modal**: The `showSearch` state variable exists but there is no `.sheet(isPresented: $showSearch)` modifier to present the `ScheduleSearchView`. The search button currently does nothing.

## Required Changes

### File: `/Users/shane/Documents/GitHub/dutypark/ios/Dutypark/Features/Duty/DutyView.swift`

Add a `.sheet` modifier to present the search view when `showSearch` is true:

```swift
.sheet(isPresented: $showSearch) {
    ScheduleSearchView(memberId: AuthManager.shared.currentUser?.id ?? 0)
}
```

This should be added after the existing `.sheet` modifiers (around line 58, after the `showAddDDay` sheet).
