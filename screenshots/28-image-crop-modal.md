# Image Crop Modal - iOS Implementation Checklist

## Screenshot Reference
The web app shows a profile photo edit modal (`28-image-crop-modal.png`) with the following features that need to be implemented in the iOS app.

## Current iOS Implementation
Located in `/ios/Dutypark/Features/Settings/SettingsView.swift`:
- Uses basic `PhotosPicker` for image selection
- Directly uploads selected image without any editing
- Uses `confirmationDialog` for photo options (select/delete)
- No crop or zoom functionality

## Missing Features

### 1. Image Crop Modal View
- [ ] Create a new `ImageCropModal` or `ProfilePhotoCropView` component
- [ ] Modal presentation with title "프로필 사진 편집"
- [ ] Close button (X) in the top-right corner

### 2. Image Preview with Circular Crop Overlay
- [ ] Display the selected image in a preview area
- [ ] Overlay a circular crop guide showing the final crop area
- [ ] Dim/darken areas outside the circular crop zone
- [ ] Support pan gestures to move the image within the crop area

### 3. Zoom Control
- [ ] Zoom slider with min/max range (e.g., 100% to 300%)
- [ ] Zoom out icon (magnifying glass with minus) on the left
- [ ] Zoom in icon (magnifying glass with plus) on the right
- [ ] Display current zoom percentage (e.g., "100%")
- [ ] Support pinch-to-zoom gesture as an alternative

### 4. Action Buttons
- [ ] "다른 이미지 선택" (Select another image) button - opens PhotosPicker
- [ ] "취소" (Cancel) button - dismisses modal without saving
- [ ] "삭제" (Delete) button - red/destructive style, deletes current profile photo
- [ ] "저장" (Save) button - blue/primary style, crops and uploads the image

### 5. Image Processing
- [ ] Crop the image based on zoom level and position
- [ ] Export cropped image as circular or square (server may handle circular masking)
- [ ] Compress to JPEG with appropriate quality before upload

## Technical Notes
- Consider using `MagnificationGesture` for pinch-to-zoom
- Consider using `DragGesture` for panning the image
- The crop area should be centered and have a fixed size relative to the view
- State management needed for: zoom scale, image offset, selected image data
