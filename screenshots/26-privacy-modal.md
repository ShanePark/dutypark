# Privacy Modal - iOS Implementation Status

## Screenshot Analysis

The screenshot shows a **Privacy Policy Modal** (개인정보 처리방침) with the following features:

### Features Shown in Screenshot

1. **Modal Header**
   - Title: "개인정보 처리방침" with close (X) button

2. **Policy Content**
   - Effective date display (시행일: 2025-01-15)
   - Introduction text explaining service commitment to privacy protection
   - Section headers (e.g., "제1조 (개인정보의 수집 항목 및 수집 방법)")
   - Subsection title: "수집하는 개인정보 항목"

3. **Data Collection Table**
   | 구분 | 수집 항목 | 필수/선택 |
   |------|----------|----------|
   | 소셜 로그인(카카오) | 이름, 카카오 계정 고유 식별자 | 필수 |
   | 서비스 이용 | 일정, 기념일(D-Day), 근무표, 할일(Todo), 첨부파일 | 선택 |
   | 관계 정보 | 친구 목록, 가족 관계, 관리자 관계 | 선택 |

4. **Footer**
   - Close button (닫기)

5. **Scrollable Content Area**
   - Markdown-rendered policy content from API

---

## Missing iOS Implementation

### 1. Policy API Client
**File to create/update:** `Core/Network/Endpoint.swift` and new `Core/Models/Policy.swift`

```swift
// Policy.swift - Data Models
struct PolicyDto: Codable {
    let policyType: String  // "TERMS" or "PRIVACY"
    let version: String
    let content: String
    let effectiveDate: String
}

struct CurrentPoliciesDto: Codable {
    let terms: PolicyDto?
    let privacy: PolicyDto?
}
```

**API Endpoints needed:**
- `GET /api/policies/current` - Fetch current terms and privacy policy
- `GET /api/policies/privacy` - Fetch privacy policy only

---

### 2. Policy Modal View
**File to create:** `Features/Policy/PolicyModalView.swift`

Required features:
- [ ] Modal presentation with title and close button
- [ ] Loading state while fetching policy content
- [ ] Markdown rendering for policy content (use `AttributedString` or third-party library)
- [ ] Scrollable content area
- [ ] Close button in footer
- [ ] Support for both "terms" and "privacy" policy types

---

### 3. LoginView Updates
**File to update:** `Features/Auth/LoginView.swift`

Required changes:
- [ ] Add policy links at the bottom of login view
- [ ] "이용약관" (Terms of Service) button
- [ ] "개인정보 처리방침" (Privacy Policy) button
- [ ] State variable to control which policy modal to show
- [ ] Integration with PolicyModalView

---

### 4. SettingsView Updates
**File to update:** `Features/Settings/SettingsView.swift`

Required changes:
- [ ] Add new section "약관 및 정책" (Terms & Policies)
- [ ] Row for "이용약관" (Terms of Service)
- [ ] Row for "개인정보 처리방침" (Privacy Policy)
- [ ] Navigation to policy modal or full-screen policy view

---

### 5. Markdown Rendering
**Consideration needed:**

The web app uses `marked` library to render Markdown content. For iOS:

Options:
1. Use `AttributedString` with Markdown support (iOS 15+)
2. Use third-party library like `MarkdownUI` (SwiftUI native)
3. Use `WKWebView` to render HTML converted from Markdown

Recommended: `AttributedString` for simple Markdown or `MarkdownUI` for complex formatting including tables.

---

## Implementation Priority

1. **High Priority** - Policy data models and API client
2. **High Priority** - PolicyModalView component
3. **Medium Priority** - LoginView integration (for legal compliance)
4. **Medium Priority** - SettingsView integration (for user accessibility)
5. **Low Priority** - Advanced Markdown table rendering

---

## Web Reference Files

- Policy API: `frontend/src/api/policy.ts`
- Policy Modal Component: `frontend/src/components/common/PolicyModal.vue`
- Login View with Policy Links: `frontend/src/views/auth/LoginView.vue`
- SSO Signup with Policy Agreement: `frontend/src/views/auth/SsoSignupView.vue`
- Standalone Privacy View: `frontend/src/views/policy/PrivacyView.vue`
