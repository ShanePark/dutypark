# 20-terms: Terms of Service View

## Screenshot Analysis

The screenshot shows the Terms of Service (이용약관) view with the following features:

1. **Page Title** - "이용약관" header
2. **Effective Date Display** - "시행일: 2025-01-15" showing when the terms became effective
3. **Scrollable Terms Content** - Full terms of service text rendered from markdown, including:
   - 제1조 (목적) - Purpose
   - 제2조 (정의) - Definitions
   - 제3조 (약관의 효력 및 변경) - Terms Effectiveness and Changes
   - Additional articles...

## Current iOS Implementation Status

**NOT IMPLEMENTED** - The iOS app does not have a Terms of Service view.

## Missing Features

### 1. Policy API Client
- [ ] Create `PolicyAPI.swift` in `Core/Network/` directory
- [ ] Implement `PolicyDto` model with fields:
  - `policyType`: String (TERMS or PRIVACY)
  - `version`: String
  - `content`: String (Markdown content)
  - `effectiveDate`: String
- [ ] Implement `getPolicy(type:)` endpoint call to `/api/policies/terms`

### 2. Terms View
- [ ] Create `TermsView.swift` in `Features/Settings/` or new `Features/Policy/` directory
- [ ] Display "이용약관" title
- [ ] Show effective date ("시행일: YYYY-MM-DD")
- [ ] Render markdown content from API response
- [ ] Add loading state indicator
- [ ] Add error state handling
- [ ] Support dark mode theming

### 3. Navigation Entry Point
- [ ] Add "이용약관" button/link in `SettingsView.swift` under a new "약관 및 정책" section
- [ ] Navigate to `TermsView` when tapped

### 4. Privacy Policy View (Related)
- [ ] Consider implementing `PrivacyView.swift` alongside TermsView
- [ ] Both can share the same pattern and PolicyDto model

## API Reference

```
GET /api/policies/terms
Response: {
  "policyType": "TERMS",
  "version": "1.0",
  "content": "## 이용약관\n\n시행일: 2025-01-15\n\n### 제1조 (목적)...",
  "effectiveDate": "2025-01-15"
}
```

## Implementation Notes

- Use SwiftUI's `Text` with AttributedString for basic markdown rendering, or consider a third-party markdown library for full support
- Follow existing iOS app patterns for API calls and view structure
- Ensure proper theming using `DesignSystem.Colors` for light/dark mode support
