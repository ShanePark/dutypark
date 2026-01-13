# 23-intro-guest: iOS Implementation Gap Analysis

## Screenshot Description
The screenshot shows the web app's guest intro view (IntroHero section) - the landing page shown to unauthenticated users.

## Web Implementation (Reference)
The web intro consists of three main sections:
1. **IntroHero**: Hero section with title, tagline, description, and CTA button
2. **IntroShowcase**: Scrollable feature showcase with typing animation
3. **IntroCTA**: Final call-to-action section

### IntroHero Content (shown in screenshot)
- **Title**: "Dutypark" (large, bold)
- **Tagline** (blue/accent color): "나와 소중한 사람들을 위한 소셜 캘린더"
- **Description**: "근무 일정, 아이 등원, 응원하는 팀의 경기까지. 서로의 일상을 공유하고 함께 계획하세요."
- **CTA Button**: "시작하기 >" (blue rounded pill button with chevron)
- **Scroll Indicator**: "스크롤하여 더 알아보기" with down arrow

### IntroShowcase Features (not in screenshot but part of full intro)
1. **일상을 함께** (Heart icon) - Schedule sharing
2. **근무 & 연차 관리** (Clock icon) - Duty management
3. **다양한 일상** (Users icon) - Various life events
4. **할일 관리** (Check icon) - Todo board
5. **D-Day 카운트다운** (Flag icon) - D-Day countdown
6. **공휴일 자동 연동** (Sun icon) - Holiday sync

### IntroCTA Content
- "소중한 사람들과 연결되세요"
- "당신의 일정은 단순한 근무 그 이상이니까요. 카카오톡으로 지금 바로 시작하세요."
- "로그인 / 회원가입" button
- "먼저 기능 둘러보기" link

## Current iOS Implementation
Located in: `/Users/shane/Documents/GitHub/dutypark/ios/Dutypark/Features/Auth/LoginView.swift`

The iOS app currently shows:
- Title: "Dutypark"
- Tagline: "근무표 관리의 시작" (DIFFERENT from web)
- Login form directly on the same screen (email/password fields)
- Kakao OAuth button (TODO)
- Signup button (TODO)

## Missing Features in iOS App

### 1. Separate Intro/Guest View
- [ ] Create a new `IntroView.swift` that shows the hero content first
- [ ] Title: "Dutypark"
- [ ] Tagline (accent color): "나와 소중한 사람들을 위한 소셜 캘린더"
- [ ] Description: "근무 일정, 아이 등원, 응원하는 팀의 경기까지. 서로의 일상을 공유하고 함께 계획하세요."
- [ ] "시작하기" CTA button that navigates to LoginView

### 2. Scroll/Swipe Feature Showcase (Optional Enhancement)
- [ ] Feature cards showing app capabilities (share, duty, life, todo, dday, holiday)
- [ ] SwiftUI PageView or ScrollView with snap behavior
- [ ] Progress indicator dots

### 3. Navigation Flow
- [ ] IntroView (guest landing) -> LoginView (authentication)
- [ ] Update `ContentView.swift` to show IntroView for unauthenticated users instead of LoginView directly

### 4. Design Alignment
- [ ] Use consistent tagline: "나와 소중한 사람들을 위한 소셜 캘린더" (not "근무표 관리의 시작")
- [ ] Accent-colored tagline text
- [ ] Rounded pill-style CTA button with chevron icon

## Priority Recommendations

### High Priority (Core UX Alignment)
1. Create `IntroView.swift` with hero section content matching the web
2. Update navigation flow: IntroView -> LoginView
3. Fix tagline to match web version

### Medium Priority (Enhanced Experience)
1. Add feature showcase with swipeable cards
2. Add progress indicator for feature pages

### Low Priority (Polish)
1. Add scroll indicator animation
2. Add entrance animations for hero elements
