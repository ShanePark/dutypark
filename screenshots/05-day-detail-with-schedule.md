# 05-day-detail-with-schedule.png - iOS Implementation Gap Analysis

## Screenshot Features vs iOS Implementation

### Implemented Features
- [x] Date header with year, month, day display
- [x] Duty type quick change buttons (OFF, work types)
- [x] Schedule card with title/content
- [x] Schedule time display
- [x] Visibility badge (home icon for private)
- [x] Schedule description text
- [x] Add schedule button
- [x] Tap to edit schedule

### Missing Features

#### 1. Tagged By Label ("by author name")
- **Screenshot**: Shows "by 이동현" label indicating who tagged the user in this schedule
- **iOS**: Not implemented in `ScheduleCard`
- **Implementation needed**: Display the schedule owner's name when viewing a tagged schedule (when the schedule is not owned by the current user)

#### 2. Remove Tag Button ("태그 제거")
- **Screenshot**: Shows "X 태그 제거" button allowing user to remove themselves from a tagged schedule
- **iOS**: Not implemented
- **Implementation needed**:
  - Add a button to remove the current user from the schedule's tags
  - This should only appear when the current user is tagged in someone else's schedule
  - API call to remove the tag

#### 3. Full-width Add Schedule Button Style
- **Screenshot**: Shows a prominent green full-width "+ 일정 추가" button at the bottom
- **iOS**: Uses a small icon button (plus.circle.fill) next to the "일정" header
- **Implementation needed**: Consider changing to a more prominent full-width button style for better UX consistency

#### 4. Day of Week in Date Header
- **Screenshot**: Shows "(토)" indicating Saturday
- **iOS**: Only shows month and day in navigation title
- **Implementation needed**: Add day of week display in the date header

## Priority
1. **High**: Tagged By Label - Important for understanding schedule context
2. **High**: Remove Tag Button - Critical user functionality for managing tagged schedules
3. **Low**: Full-width button style - UX improvement
4. **Low**: Day of week display - Minor enhancement
