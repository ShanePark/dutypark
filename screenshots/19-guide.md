# 19-guide.png - iOS Implementation Checklist

## Screenshot Overview
This screenshot shows the "이용 안내" (Usage Guide/Help) page in the web application. It provides users with comprehensive documentation about Dutypark's features and how to use them.

## Features Shown in Screenshot

### 1. Guide Page Header
- Title: "이용 안내" with icon
- Subtitle: "Dutypark의 주요 기능과 사용 방법을 안내합니다"
- "모두 펼치기" / "모두 접기" (Expand All / Collapse All) buttons

### 2. Expandable Accordion Sections
The guide uses an accordion pattern with expandable sections:

#### 대시보드 (홈) Section
- Description of the dashboard as the first screen after login
- Shows today's duty and schedules at a glance
- Allows quick view of friends' status

#### 오늘의 정보 확인 Subsection
- Today's date and day of week display
- Current assigned duty type display
- Today's scheduled items list
- Friend-tagged schedules shown with "(by name)" format
- Tap header area to navigate to my calendar

#### 친구 목록 Subsection
- View registered friends' today's duty and schedules
- Tap friend card to navigate to that friend's calendar

### 3. Additional Sections (not visible in screenshot)
- Likely includes: Calendar, Schedule, Todo, Team, Settings, etc.

## iOS Implementation Status

### Missing Components

1. **GuideView.swift** - Main guide view component
   - [ ] Create new file at `/ios/Dutypark/Features/Guide/GuideView.swift`
   - [ ] Implement accordion-style expandable sections using `DisclosureGroup`
   - [ ] Add "Expand All / Collapse All" functionality
   - [ ] Match dark mode styling from other views

2. **Guide Content Sections**
   - [ ] Dashboard (홈) section content
   - [ ] Calendar (내 달력) section content
   - [ ] Schedule (일정) section content
   - [ ] Todo (할일) section content
   - [ ] Team (내 팀) section content
   - [ ] Settings (설정) section content
   - [ ] Friends (친구) section content

3. **Navigation Integration**
   - [ ] Add Guide entry point (options):
     - Settings page link to guide
     - Help button in individual views (like the one in TodoBoardView.swift line 77-84)
     - Or dedicated menu item

4. **TodoBoardView Help Button**
   - [ ] Currently has placeholder at lines 77-84 with `// Show help` comment
   - [ ] Implement actual navigation to guide or show relevant help sheet

### Implementation Notes

- Use `DisclosureGroup` for accordion sections
- Consider using `@State` array to track expanded/collapsed state of all sections
- "Expand All / Collapse All" should toggle all sections simultaneously
- Follow existing design system (DesignSystem.swift) for colors, spacing, and typography
- Support both light and dark mode
- Use Korean text for all content labels
