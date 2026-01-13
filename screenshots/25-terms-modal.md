# Terms Modal - iOS Implementation Required

## Screenshot Analysis

The screenshot shows a Terms of Service (이용약관) modal with the following features:

### Features Shown in Screenshot

1. **Modal Header**
   - Title: "이용약관" (Terms of Service)
   - Close button (X) in the top-right corner

2. **Modal Body**
   - Scrollable content area displaying terms text
   - Content includes:
     - Effective date (시행일: 2025-01-15)
     - Article 1: Purpose (제1조 목적)
     - Article 2: Definitions (제2조 정의)
     - Article 3: Terms Effectiveness and Changes (제3조 약관의 효력 및 변경)
     - And more articles...

3. **Modal Footer**
   - "닫기" (Close) button at the bottom

## iOS App Current State

The iOS app does **NOT** have any terms/policy related implementation:
- No Terms modal or view
- No Privacy Policy modal or view
- No link to terms in Settings
- No policy API client

## Required Implementation

### 1. API Client - Add Policy Endpoints

**File:** `/ios/Dutypark/Core/Network/Endpoint.swift`

Add endpoints:
```swift
// Policy endpoints
case getCurrentPolicies
case getPolicy(type: String)  // "TERMS" or "PRIVACY"
```

### 2. Model - Add Policy DTOs

**New file:** `/ios/Dutypark/Core/Models/Policy.swift`

```swift
struct PolicyDto: Codable, Identifiable {
    let policyType: String  // "TERMS" or "PRIVACY"
    let version: String
    let content: String
    let effectiveDate: String

    var id: String { "\(policyType)-\(version)" }
}

struct CurrentPoliciesDto: Codable {
    let terms: PolicyDto?
    let privacy: PolicyDto?
}
```

### 3. Component - Policy Modal

**New file:** `/ios/Dutypark/Components/PolicyModal.swift`

A modal sheet that:
- Takes policy type ("terms" or "privacy") as parameter
- Fetches policy content from API
- Displays content in a scrollable view with markdown rendering
- Has a close button in header and footer

### 4. Settings Integration

**File:** `/ios/Dutypark/Features/Settings/SettingsView.swift`

Add a new section "약관 및 정책" (Terms & Policies) with:
- "이용약관" (Terms of Service) - opens PolicyModal with type "terms"
- "개인정보 처리방침" (Privacy Policy) - opens PolicyModal with type "privacy"

## API Reference

Based on web frontend implementation:

```
GET /api/policies/current
Response: {
  "terms": { "policyType": "TERMS", "version": "...", "content": "...", "effectiveDate": "..." },
  "privacy": { "policyType": "PRIVACY", "version": "...", "content": "...", "effectiveDate": "..." }
}

GET /api/policies/terms
Response: { "policyType": "TERMS", "version": "...", "content": "...", "effectiveDate": "..." }

GET /api/policies/privacy
Response: { "policyType": "PRIVACY", "version": "...", "content": "...", "effectiveDate": "..." }
```

## Priority

Medium - Required for app store compliance and user transparency.
