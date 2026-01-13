# Todo Detail Modal - iOS Implementation Status

## Screenshot Analysis

The screenshot shows the web version of Todo Detail Modal with the following features:

### Identified Features in Screenshot

1. **Header Section**
   - Todo title ("ㅇㅇㅇ")
   - Status badge ("진행중" - yellow, indicating IN_PROGRESS)
   - Created date/time ("2026년 1월 13일 18:40")
   - Close button (X)

2. **Content Section**
   - Todo content/description ("ㅇㅇㅇ")

3. **Action Bar (Bottom)**
   - List button (back to list)
   - Edit button (pencil icon, blue)
   - Delete button (trash icon, red)
   - Complete button (checkmark icon, green)

## Missing Features in iOS Implementation

### 1. Attachment Display (View Mode)
- **Web**: Displays attachments using `AttachmentGrid` component
- **iOS**: `Todo` model has `attachments: [Attachment]?` field but `TodoDetailSheet` does not display them
- **Priority**: High

### 2. Attachment Upload/Edit (Edit Mode)
- **Web**: Supports file upload via `FileUploader` component with session management
- **iOS**: Edit mode does not include attachment upload functionality
- **Priority**: High

### 3. Completed Date Display
- **Web**: Shows "완료 {completedDate}" when todo is completed
- **iOS**: Does not display `completedDate` even though it's available in the model
- **Priority**: Low

## Existing Features (Already Implemented)

- Title display
- Status badge (TodoStatusBadge component)
- Created date display
- Content display
- Due date display with overdue warning
- Edit mode with title, content, due date editing
- Status change functionality
- Delete functionality with confirmation
- Close/dismiss functionality

## Implementation Notes

### For Attachment Display
- Use `Attachment` model already defined in `Core/Models/Attachment.swift`
- Need to create an attachment grid/list view component
- Consider using AsyncImage for thumbnail loading via API endpoint

### For Attachment Upload
- `CreateSessionRequest` and `CreateSessionResponse` already exist
- Need to implement file picker and upload flow similar to `ScheduleEditView` (if implemented there)

### API Endpoints to Use
- GET attachments: Already available via Todo model's attachments array
- For upload: Use `/api/attachments/sessions` endpoint with context type "TODO"
