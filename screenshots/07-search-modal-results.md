# Schedule Search Results - Missing iOS Features

## Reference Screenshot
The web app shows a schedule search modal with search results displaying search count and date/time ranges.

## Currently Implemented in iOS
- Search modal with NavigationStack ("일정 검색")
- SearchBar component with placeholder and clear button
- Search results list with schedule content
- Visibility badge display
- Description and tags display
- Loading state (ProgressView)
- Empty state views

## Missing Features

### 1. Search Button
- **Web:** Blue "검색" (Search) button next to the search input field
- **iOS:** No explicit search button; search only triggers on text change or submit
- **Action:** Add a blue "검색" button to the right of the SearchBar

### 2. Search Result Count
- **Web:** Shows ""결혼" 검색 결과 9건" (9 results for "결혼")
- **iOS:** No result count displayed
- **Action:** Add a text showing the search query and result count below the search bar

### 3. Date/Time Format
- **Web:** Shows "2026-01-03 14:00 ~ 14:00" format with full date and time range
- **iOS:** Shows only "2024.10.5" with separate clock icon for start time only
- **Action:** Update `formatDate` to show "yyyy-MM-dd HH:mm ~ HH:mm" format including both start and end times

### 4. End Time Display
- **Web:** Displays both start and end times in a range format (e.g., "14:00 ~ 14:00")
- **iOS:** Only displays start time if available
- **Action:** Include `schedule.endTime` in the display, showing "startTime ~ endTime" format

### 5. Card-Style UI
- **Web:** Each search result appears in a card with distinct background (light card on dark background)
- **iOS:** Uses default List style without card appearance
- **Action:** Consider adding card-style background to each result row with rounded corners and distinct background color

## Implementation Priority
1. Date/Time format with time range (High) - Core functionality difference
2. Search result count (Medium) - User feedback improvement
3. Search button (Low) - UX enhancement, current behavior is acceptable
4. Card-style UI (Low) - Visual polish, not blocking functionality

## Files to Modify
- `/Users/shane/Documents/GitHub/dutypark/ios/Dutypark/Features/Schedule/ScheduleListView.swift`
  - `ScheduleSearchView` - Add result count display and search button
  - `ScheduleSearchResultRow` - Update date/time format to show range
