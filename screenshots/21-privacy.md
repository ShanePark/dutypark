# 21-privacy: Privacy Policy View

## Screenshot Description
The screenshot shows the **Privacy Policy (개인정보 처리방침)** view in the web app, displaying:
- Title: "개인정보 처리방침"
- Effective date: 2025-01-15
- Description of the service's privacy policy
- Article 1 (Collection items and methods for personal information)
- Table showing collected personal information:
  | Category | Collected Items | Required/Optional |
  |----------|-----------------|-------------------|
  | Social Login (Kakao) | Name, Kakao account unique identifier | Required |
  | Service Usage | Schedules, D-Day, Duty calendar, Todos, Attachments | Optional |
  | Relationship Info | Friends list, Family relations, Manager relations | Optional |
  | Profile | Profile photo | Optional |

## Missing Features in iOS App

### 1. PrivacyPolicyView
- **Location**: Create new file at `Features/Settings/PrivacyPolicyView.swift`
- **Description**: A view to display the privacy policy content
- **Requirements**:
  - Fetch privacy policy content from API
  - Render markdown content
  - Display title "개인정보 처리방침"
  - Show effective date
  - Support scrolling for long content
  - Match the design of the web app (dark mode support)

### 2. Policy API Endpoint
- **Location**: Add to `Core/Network/Endpoint.swift`
- **Endpoints needed**:
  ```swift
  // Get specific policy (PRIVACY or TERMS)
  static func policy(type: String) -> Endpoint {
      Endpoint(path: "/policies/\(type.lowercased())")
  }
  ```

### 3. Policy Model
- **Location**: Create new file at `Core/Models/Policy.swift`
- **Model**:
  ```swift
  struct PolicyDto: Codable {
      let policyType: String  // "TERMS" or "PRIVACY"
      let version: String
      let content: String
      let effectiveDate: String
  }
  ```

### 4. Settings View Link
- **Location**: Update `Features/Settings/SettingsView.swift`
- **Description**: Add a navigation link to the Privacy Policy view in the account management section
- **Requirements**:
  - Add new section or row for "개인정보 처리방침"
  - Use NavigationLink to navigate to PrivacyPolicyView
  - Icon suggestion: `doc.text` or `lock.shield`

### 5. Markdown Rendering
- **Note**: The privacy policy content is stored in markdown format
- **Options**:
  - Use native SwiftUI Text with AttributedString
  - Use a third-party markdown library (e.g., MarkdownUI)
  - Simple HTML rendering via WKWebView

## Implementation Priority
1. Policy Model - Low effort
2. Policy API Endpoint - Low effort
3. PrivacyPolicyView - Medium effort (includes markdown rendering)
4. Settings View Link - Low effort

## Reference Files
- Web implementation: `frontend/src/views/policy/PrivacyView.vue`
- Web API: `frontend/src/api/policy.ts`
- iOS Settings: `ios/Dutypark/Features/Settings/SettingsView.swift`
