# TeamView iOS Implementation Gap Analysis

## Screenshot Features vs iOS Implementation

### Implemented Features

1. **Team Selector** - Team name displayed with building icon
2. **Month Navigation** - Year-month display with left/right navigation arrows
3. **Settings Button** - Gear icon visible for team managers, navigates to TeamManageView
4. **Calendar Grid** - Full calendar with weekday headers
5. **Weekday Color Coding** - Sunday (red), Saturday (blue), weekdays (default)
6. **Weekend Background** - Pink/different background for weekend cells
7. **Today Highlight** - Red border around current date
8. **Selected Date Display** - Shows selected date in "YYYY년 M월 D일" format
9. **Add Team Schedule Button** - Green "팀 일정 추가" button for managers
10. **Empty State Message** - "이 날의 팀 일정이 없습니다."
11. **Team Schedule Cards** - Display team schedules for selected day
12. **Shift/Duty Member Display** - Shows team members by duty type

### Missing Features

1. **Holiday Display in Calendar Cells**
   - **Location:** `TeamView.swift` → `TeamDayCell`
   - **Issue:** The web app shows holiday names (e.g., "신정" for New Year's Day) inside calendar day cells. The iOS TeamView does not load or display holidays.
   - **Reference Implementation:** The DutyView (`DutyView.swift`) already implements this feature with `viewModel.holidays[day]` and displays the holiday name in the `DayCell` component.
   - **Required Changes:**
     - Add `holidays: [Int: String]` property to `TeamViewModel`
     - Add `loadHolidays()` function to `TeamViewModel` (can copy from `DutyViewModel`)
     - Call `loadHolidays()` in `loadTeamData()` function
     - Update `TeamDayCell` to accept `holidayName: String?` parameter
     - Display holiday name in `TeamDayCell` similar to `DayCell`
     - Update text color logic to use red for holidays (like DutyView does)
     - Update background color logic to apply weekend/holiday background for holidays
