# Team Manage View - iOS Implementation Gap Analysis

## Screenshot Reference
`29-team-manage.png` - Team management screen showing team info, duty schedule upload, and member management

## Currently Implemented in iOS

1. **Team Info Section** (Read-only)
   - Team name display
   - Description display
   - Admin name display
   - Work type display (read-only)

2. **Team Members Section**
   - Member list with profile photos
   - Add member (search and add)
   - Remove member from team
   - Grant/revoke manager role

3. **Duty Types Section** (Read-only)
   - Duty type list with colors

## Missing Features

### 1. Duty Batch Template Selection
- **Web Feature**: Dropdown to select duty batch import template (e.g., "성심당 케익부띠끄")
- **API**: `PUT /api/teams/manage/{teamId}/batch-template`
- **Priority**: High (visible in screenshot)

### 2. Duty Schedule Upload (Excel Import)
- **Web Feature**: "등록" button to upload Excel file (.xlsx) for batch duty import
- **API**: `POST /api/teams/manage/{teamId}/duty-batch`
- **Requirements**:
  - File picker for .xlsx files
  - Year and month selection
  - Upload progress indicator
- **Priority**: High (visible in screenshot)

### 3. Work Type Modification
- **Current State**: iOS displays work type as read-only text
- **Web Feature**: Dropdown to change work type (평일 근무, 주말 근무, 고정 근무, 유연 근무)
- **API**: `PUT /api/teams/manage/{teamId}/work-type`
- **Priority**: Medium

### 4. Admin (Team Representative) Management
- **Web Feature**:
  - Display current admin
  - Reset admin (remove current admin)
  - Delegate admin role to another manager
- **API**: `PUT /api/teams/manage/{teamId}/admin`
- **Priority**: Medium

### 5. Duty Type Management (CRUD)
- **Current State**: iOS shows read-only list
- **Web Features**:
  - Add new duty type
  - Edit duty type (name, color)
  - Delete duty type
  - Reorder duty types (swap positions)
  - Color picker for duty type colors
- **APIs**:
  - `POST /api/teams/manage/{teamId}/duty-types` (create)
  - `PUT /api/teams/manage/{teamId}/duty-types/{dutyTypeId}` (update)
  - `DELETE /api/teams/manage/{teamId}/duty-types/{dutyTypeId}` (delete)
  - `PUT /api/teams/manage/{teamId}/duty-types/swap` (reorder)
  - `PUT /api/teams/manage/{teamId}/default-duty` (update default/OFF duty)
- **Priority**: Medium

## Implementation Notes

- The duty batch upload feature requires document picker functionality in iOS
- Color picker for duty types can use native iOS color picker (available in iOS 14+)
- File upload should show progress and handle errors appropriately
- All management features should only be visible/enabled for team managers (check `isCurrentUserManager()`)
