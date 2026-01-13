# Todo Board - Missing iOS Features

Comparison between web screenshot and iOS implementation at `/ios/Dutypark/Features/Todo/TodoBoardView.swift`

## Missing Features

### 1. Drag-and-Drop Reordering
**Priority: Medium**

The web version supports full drag-and-drop functionality using SortableJS:
- Drag cards between columns to change status
- Drag cards within a column to reorder them
- Visual feedback during drag (ghost, chosen, fallback states)

The iOS version only supports:
- Context menu for changing status (long-press on card)
- No drag-and-drop gesture support
- No reordering within columns

**Implementation Notes:**
- Consider using SwiftUI's `onDrag` and `onDrop` modifiers
- Or implement custom gesture recognizers for drag interactions
- API endpoints exist: `todoApi.updatePositions()` and `todoApi.changeStatus()` with `orderedIds`

### 2. Help Modal Content
**Priority: Low**

The web version has a detailed help modal with:
- Explanation of what a Kanban board is
- Description of each column (TODO, IN_PROGRESS, DONE)
- Highlight that "IN_PROGRESS" items appear on the calendar
- Usage tips (drag-drop, reordering, due dates, attachments)

The iOS version has the help button UI but the action is not implemented:
```swift
// Line 78-80 in TodoBoardView.swift
Button {
    // Show help
} label: {
```

**Implementation Notes:**
- Create a sheet or alert with help content
- Match the web modal's sections:
  - "Kanban board concept"
  - "TODO column explanation"
  - "IN_PROGRESS column explanation" (with calendar highlight)
  - "DONE column explanation"
  - "Usage tips"

## Already Implemented Features

The following features from the screenshot are already working in iOS:
- Header with title ("할일") and total count badge
- Filter tabs (모든 할일, 할 일, 진행중, 완료)
- Kanban columns with header icons, titles, counts, and add buttons
- Todo cards displaying title, content, due date, and attachment indicators
- Add todo sheet with title, description, due date, and status
- Todo detail sheet with edit, status change, and delete functionality
- Pull-to-refresh to reload board
- Context menu for quick status changes
- Overdue date highlighting
