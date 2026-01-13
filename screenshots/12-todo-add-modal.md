# Todo Add Modal - Missing iOS Features

## Screenshot Reference
`12-todo-add-modal.png`

## Missing Features in iOS `AddTodoSheet.swift`

### 1. Status Selection UI
- **Web**: Shows three selectable status buttons (chips) with icons:
  - "오늘 할일" (Today's Todo) - with checkbox icon
  - "진행중" (In Progress) - with clock icon
  - "완료" (Complete) - with checkmark icon
- **iOS**: Only displays the initial status as a read-only badge (`TodoStatusBadge`)
- **Required**: Allow users to select/change status when creating a todo

### 2. Title Character Counter
- **Web**: Shows character counter "0/50" next to the title label
- **iOS**: No character counter displayed
- **Required**: Add character limit indicator (50 characters max)

### 3. File Attachment Feature
- **Web**: Has a dedicated "첨부파일" (Attachments) section with:
  - "파일 추가" (Add File) button with upload icon
  - Dashed border upload area
- **iOS**: Completely missing
- **Required**: Implement file attachment capability with image/file picker

## Implementation Priority
1. **High**: Status Selection UI - Core functionality difference
2. **Medium**: File Attachment - Feature parity with web
3. **Low**: Character Counter - Nice-to-have UX improvement
