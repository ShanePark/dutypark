# Duty Compare View - iOS Implementation Status

## Screenshot Analysis

The screenshot shows a duty calendar view for **another user** (이동헌), demonstrating the "Duty Compare View" feature where users can view friends' calendars.

## Features Shown in Screenshot

### 1. Friend's Calendar Navigation
- **Status**: NOT IMPLEMENTED
- Header displays friend's profile avatar and name (이동헌)
- Users can navigate to view any friend's duty calendar

### 2. Compare View Selector (함께보기)
- **Status**: NOT IMPLEMENTED
- Button with "(1)" badge indicating number of friends being compared
- Opens a modal (OtherDutiesModal) to select up to 3 friends
- Allows overlay comparison of multiple friends' duties

### 3. Other Duties Display on Calendar
- **Status**: NOT IMPLEMENTED
- Multiple friends' duty types displayed as mini badges on each day
- Shows duty type name and color for each compared friend
- Example: "박세헌: 출근", "박세헌: 한:OFF"

### 4. Schedule Tags Display
- **Status**: PARTIALLY IMPLEMENTED (in DayDetailSheet)
- Schedule entries show tagged friend avatars/names
- Example: Schedule "김윤혜 결혼식" shows tags "박세헌", "박꾸니"
- Calendar grid should show tag indicators

### 5. Current Features Working
- D-Day cards at bottom (IMPLEMENTED)
- Basic calendar grid with duties (IMPLEMENTED)
- Holiday display (IMPLEMENTED)
- Today indicator with red border (IMPLEMENTED)
- Duty type legend with counts (IMPLEMENTED)

## Implementation Requirements

### High Priority

1. **FriendDutyView.swift** (New)
   - Create a view similar to DutyView but for viewing a friend's calendar
   - Accept `memberId` parameter to load friend's data
   - Display friend's profile info in header
   - Load friend's duties, schedules, and D-Days
   - Disable edit mode (read-only view)

2. **Update FriendsView.swift**
   - Modify FriendCard tap action to navigate to FriendDutyView
   - Pass selected friend's ID for calendar navigation

### Medium Priority

3. **CompareViewModal.swift** (New)
   - Modal to select friends for comparison (max 3)
   - Show friend list with checkboxes
   - Display selection count

4. **Update DutyView.swift**
   - Add "함께보기" button in header
   - Load and display other duties from selected friends
   - Modify DayCell to show multiple friends' duties

5. **Update DutyViewModel.swift**
   - Add `otherDuties` state property
   - Add `selectedFriendIds` for comparison
   - Implement `loadOtherDuties()` method using existing `Endpoint.otherDuties`

### Low Priority

6. **Tag Display Enhancement**
   - Show tag indicators on calendar day cells
   - Display small avatars or initials of tagged friends

## API Endpoints (Already Available)

The iOS app already has the necessary API endpoints defined:
- `Endpoint.duties(memberId:year:month:)` - Load any member's duties
- `Endpoint.otherDuties(memberIds:year:month:)` - Load multiple friends' duties for comparison
- `Endpoint.friends` - Get friend list for compare selector
