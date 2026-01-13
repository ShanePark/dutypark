# Login Screen - iOS Implementation Status

## Screenshot Reference
Web login screen at `/screenshots/24-login.png`

## Features Comparison

### Implemented
- [x] Dutypark title text
- [x] Subtitle text (different wording: iOS uses "근무표 관리의 시작", web uses "로그인하여 시작하세요")
- [x] Email input field with placeholder
- [x] Password input field with placeholder
- [x] Login button with loading state
- [x] Kakao login button (basic - needs styling improvements)

### Missing Features

1. **"아이디 저장" (Remember Email) Checkbox**
   - Web has a checkbox to save the email address
   - iOS implementation lacks this feature
   - Should persist email using UserDefaults or Keychain

2. **"또는" Divider Line**
   - Web shows a horizontal divider with "또는" (or) text between login form and Kakao button
   - iOS does not have this visual separator

3. **Kakao Login Button Styling**
   - Web uses yellow background (#FEE500) with Kakao icon
   - iOS uses default bordered button style
   - Should match the distinctive Kakao yellow color and include the Kakao symbol

4. **"홈으로 돌아가기" (Go to Home) Link**
   - Web has a link to navigate back to home
   - iOS does not have this navigation option (may not be applicable for mobile app)

5. **"이용약관 | 개인정보 처리방침" (Terms of Service | Privacy Policy) Footer Links**
   - Web displays legal links at the bottom
   - iOS implementation is missing these links
   - Should link to terms and privacy policy pages/views

6. **Subtitle Text Mismatch**
   - Web: "로그인하여 시작하세요"
   - iOS: "근무표 관리의 시작"
   - Consider aligning the text for consistency

### Extra Features in iOS (Not in Web Screenshot)
- "회원가입" (Sign up) button - This may be intentional for mobile UX

## Priority Recommendations

1. **High Priority**
   - Kakao login button styling (brand compliance)
   - Terms/Privacy links (legal requirement)

2. **Medium Priority**
   - "아이디 저장" checkbox (UX improvement)
   - "또는" divider (visual consistency)

3. **Low Priority**
   - Subtitle text alignment
   - "홈으로 돌아가기" link (may not be needed in mobile app context)
