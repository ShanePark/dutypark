# 02-duty-calendar.png - iOS Implementation Status

## Screenshot Analysis

The screenshot shows the duty calendar view with the following features:

### Implemented Features (Complete)

| Feature | iOS Implementation | Notes |
|---------|-------------------|-------|
| Profile avatar + username | `DutyView.headerSection` | ProfileAvatar component |
| Year-month navigation | `DutyViewModel.previousMonth/nextMonth/goToToday` | Working |
| Search button UI | `DutyView.headerSection` | UI present |
| Filter buttons UI | `DutyView.filterButtonsSection` | UI present |
| Duty type filter buttons | Dynamic from `dutyTypeNames` | UI present |
| Legend section | `DutyView.legendSection` | Shows OFF and duty type counts |
| Edit mode button UI | `DutyView.legendSection` | UI present |
| Weekday headers | `DutyView.weekdayHeaders` | Sunday red, Saturday blue |
| Calendar grid | `DutyView.calendarGrid` | 7-column grid |
| Weekend/holiday background | `DayCell.backgroundColor` | Pink background |
| Day numbers | `DayCell` | With color coding |
| Holiday names | `DayCell` | Displays holiday name |
| Duty type badge | `DayCell` | Circle + duty type name |
| Schedule previews | `DayCell` | Shows up to 2 schedules |
| Todo indicators | `DayCell` | Colored dots |
| Today highlight | `DayCell` | Red border |
| D-Day section | `DutyView.ddaySection` | 2-column grid |
| D-Day cards | `DDayCard` | Shows title, date, D-count |
| D-Day add button | `showAddDDay` + `AddDDaySheet` | Working |
| Day tap -> detail sheet | `DayDetailSheet` | Working |
| Duty change | `DutyViewModel.changeDuty` | Working |

---

## Missing or Incomplete Features

### 1. Search Functionality
- **Status**: UI only, no implementation
- **Web feature**: Search button opens schedule/event search
- **iOS current**: `showSearch` state exists but no search view implemented
- **Required**: Create `ScheduleSearchView` and connect to search button

### 2. Filter Button Actions
- **Status**: UI only, no implementation
- **Web feature**:
  - "Todo" filter button filters calendar by todo status
  - Duty type buttons filter by specific duty types
  - "+" button opens add schedule sheet
  - Filter icon opens filter/sort options
- **iOS current**: Buttons render but `action: {}` is empty
- **Required**:
  - Implement filter state management in `DutyViewModel`
  - Add schedule action -> open `ScheduleEditView`
  - Duty type filter toggle functionality

### 3. Edit Mode Toggle
- **Status**: UI only, no implementation
- **Web feature**: Toggle edit mode to enable/disable duty editing
- **iOS current**: Button UI present, no toggle action
- **Required**: Implement edit mode state and conditional UI changes

### 4. Schedule Preview - Attachment Icon
- **Status**: Not implemented
- **Web feature**: Shows camera icon (📷) when schedule has attachments
- **iOS current**: `DayCell` shows schedule content only
- **Required**: Check `schedule.attachments` and show attachment indicator

### 5. Schedule Preview - Tagged Friends Display
- **Status**: Not implemented
- **Web feature**: Shows "by [friend name]" below schedule when tagged
- **iOS current**: Tags not displayed in calendar cell preview
- **Required**: Add tagged friend name to schedule preview in `DayCell`

### 6. D-Day Favorite (Star) Toggle
- **Status**: Not implemented
- **Web feature**: Star icon (⭐) next to D-Day card for favoriting
- **iOS current**: `DDayCard` has no favorite/star functionality
- **Required**:
  - Add `isFavorite` field handling
  - Add star button to `DDayCard`
  - Implement favorite toggle API call

### 7. D-Day Edit Functionality
- **Status**: Partially implemented
- **Web feature**: Edit existing D-Day
- **iOS current**: `DDayCard` has `onEdit` parameter but `DutyView.ddaySection` only passes `onDelete`
- **Required**: Pass `onEdit` handler and create edit sheet

---

## Priority Recommendations

### High Priority
1. **D-Day Edit Functionality** - User cannot edit D-Days, only delete
2. **Add Schedule Button** - "+" button should open schedule creation

### Medium Priority
3. **Search Functionality** - Important for finding past schedules
4. **Schedule Preview Enhancements** - Attachment icon, tagged friend display

### Low Priority
5. **Filter Buttons** - Nice to have for power users
6. **Edit Mode Toggle** - Alternative to day tap -> detail sheet
7. **D-Day Favorite** - Nice to have

---

## File References

- `/Users/shane/Documents/GitHub/dutypark/ios/Dutypark/Features/Duty/DutyView.swift`
- `/Users/shane/Documents/GitHub/dutypark/ios/Dutypark/Features/Duty/DutyViewModel.swift`
- `/Users/shane/Documents/GitHub/dutypark/ios/Dutypark/Features/Duty/DayDetailSheet.swift`
- `/Users/shane/Documents/GitHub/dutypark/ios/Dutypark/Features/DDay/DDayCard.swift`
