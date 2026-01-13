# D-Day Detail Modal - iOS Implementation Checklist

## Screenshot Analysis
The web application's D-Day Detail Modal (09-dday-detail-modal.png) displays:
- Modal title: "디데이 상세" (D-Day Detail)
- Large D-Day badge (e.g., "D+854") with gradient styling
- Title section with label "제목" showing the D-Day title
- Date section with label "날짜" showing formatted date (e.g., "2023년 9월 13일 수요일")
- "캘린더에 고정하기" (Pin to calendar) toggle with star icon
- Edit button (수정) with pencil icon
- Delete button (삭제) with trash icon
- Close button (닫기)

## Current iOS Implementation
The iOS app has:
- `DDayListView.swift` - Lists D-Days in sections (upcoming/past)
- `DDayCard.swift` - Card component with edit/delete buttons that directly opens edit sheet
- `AddDDaySheet.swift` - Used for both creating and editing D-Days
- `DDayViewModel.swift` - ViewModel with CRUD operations
- `DDayBadge.swift` - Small badge component for displaying D-Day count

## Missing Features

### 1. DDayDetailSheet (Priority: High)
**File to create:** `ios/Dutypark/Features/DDay/DDayDetailSheet.swift`

The iOS app currently skips the detail view and goes directly to edit mode when tapping a D-Day card. A dedicated detail sheet should be created to match the web app's UX:

- [ ] Create `DDayDetailSheet.swift` as a presentation sheet
- [ ] Display modal title "디데이 상세"
- [ ] Show large D-Day badge (similar style to web - larger than current `DDayBadge`)
- [ ] Display title with "제목" label
- [ ] Display formatted date with "날짜" label (Korean format: "yyyy년 M월 d일 (E)")
- [ ] Include "캘린더에 고정하기" toggle (see feature #2)
- [ ] Add Edit button that opens `AddDDaySheet` in edit mode
- [ ] Add Delete button with confirmation dialog
- [ ] Add Close/닫기 button

### 2. Pin to Calendar Feature (Priority: Medium)
**Files to modify:**
- `ios/Dutypark/Features/DDay/DDayDetailSheet.swift` (new)
- `ios/Dutypark/Features/DDay/DDayViewModel.swift`
- `ios/Dutypark/Features/Duty/DutyView.swift` (or `DutyViewModel.swift`)

The web app stores pinned D-Day in localStorage with key `selectedDday_{memberId}`. iOS should use `UserDefaults` or similar:

- [ ] Add `pinnedDDayId` state to `DDayViewModel` or create a dedicated storage
- [ ] Use `UserDefaults` to persist pinned D-Day ID per member
- [ ] Add toggle functionality in `DDayDetailSheet`
- [ ] Display pinned D-Day prominently on the Duty/Calendar view (like web app does)

### 3. Large D-Day Badge for Detail View (Priority: Low)
**File to create/modify:** Could extend `DDayBadge.swift` or create new component

The detail modal shows a larger, more prominent badge style:
- [ ] Create a larger variant of D-Day badge for detail view
- [ ] Match styling: larger font size, more padding, prominent gradient
- [ ] Could add `.large` size variant to existing `DDayBadge` component

## Implementation Notes

### Pin to Calendar Storage Pattern (Web Reference)
```javascript
// Web implementation uses localStorage
localStorage.setItem(`selectedDday_${memberId}`, String(dday.id))
localStorage.getItem(`selectedDday_${memberId}`)
localStorage.removeItem(`selectedDday_${memberId}`)
```

iOS equivalent using UserDefaults:
```swift
// Store
UserDefaults.standard.set(ddayId, forKey: "selectedDday_\(memberId)")
// Retrieve
UserDefaults.standard.integer(forKey: "selectedDday_\(memberId)")
// Remove
UserDefaults.standard.removeObject(forKey: "selectedDday_\(memberId)")
```

### UI Flow Change Required
Current: `DDayCard` tap -> `AddDDaySheet` (edit mode)
Target: `DDayCard` tap -> `DDayDetailSheet` -> Edit button -> `AddDDaySheet` (edit mode)

Update `DDayListView.swift` to:
1. Add `@State private var selectedDDay: DDayDto?` for detail sheet
2. Add `.sheet(item: $selectedDDay)` presenting `DDayDetailSheet`
3. Modify `DDayCard` to set `selectedDDay` instead of `ddayToEdit`
