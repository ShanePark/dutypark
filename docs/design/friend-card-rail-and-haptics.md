# 친구 카드 rail 통일 · 태그 셀렉터 정리 · iOS 햅틱

## 배경

- 스케줄/투두의 친구 태그 셀렉터는 이미 "3:4 포트레이트 카드 + 가로 rail(3.2장 노출)"로 구현되어 있다.
  - 웹: `frontend/src/components/common/FriendTagSelector.vue`
  - iOS: `ios/Dutypark/Components/DPFriendTagSelector.swift`
- 홈 친구 목록은 그와 다른 모양이다.
  - 웹 `frontend/src/views/dashboard/DashboardView.vue`: 2열 그리드 가로형 카드
  - iOS `ios/Dutypark/Features/Home/HomeView.swift`: 세로 전체폭 행(`FriendSummaryCard`)
- 순서 변경(핀 친구 드래그)은 홈과 친구관리 양쪽에 **중복 구현**되어 있다.

## 결정 사항

| # | 결정 |
|---|---|
| D1 | 홈 친구 목록을 태그 셀렉터와 같은 포트레이트 카드 rail로 통일한다 |
| D2 | 홈 카드 내용 = 사진 + 이름 + 팀(자리 항상 확보) + **오늘 근무 배지**. 일정 미리보기는 제거 |
| D3 | 홈에서 순서 변경(드래그/롱프레스/접근성 이동 액션)을 완전히 제거한다 |
| D4 | 핀(별) 토글 버튼은 홈 카드에 **유지**한다 |
| D5 | 친구관리(웹 `FriendsView.vue`, iOS `SocialView.swift`)는 **현행 유지** — 목록 모양도, 순서 변경도 그대로 |
| D6 | 웹 데스크톱도 rail 유지 + 화살표 네비(태그 셀렉터의 `hover:hover` 패턴 재사용) |
| D7 | 태그 셀렉터 카드: 팀이 없어도 팀 줄 자리를 그대로 차지시켜 **모든 카드 높이·모양을 동일**하게 만든다 |
| D8 | 태그 셀렉터의 선택된 친구 목록을 검색창 **위 → 아래(rail 밑)** 로 옮긴다 |
| D9 | iOS에 "표준 세트" 햅틱을 추가한다 |

백엔드 변경 없음. `PATCH /friends/pin/order` 는 친구관리에서 계속 쓰인다.

## 카드 스펙 (홈 rail · 웹/iOS 공통)

```
┌──────────────┐
│              │  3:4 포트레이트 사진 (radius 8)
│    [사진]     │  · 우상단에 핀 별 오버레이 (D4)
│              │  · 사진 없으면 이름 첫 글자 타일
├──────────────┤
│    이름       │  bold 12 / 0.75rem, 1줄, 축소 허용
│    팀         │  light 10 / 0.625rem, 1줄 — 값이 없어도 자리 유지 (D7)
│  [ 근무 ]     │  근무 배지, 1줄 — 값이 없으면 "-" (D2)
└──────────────┘
```

- 카드 폭: 모바일·태블릿은 태그 셀렉터와 동일한 3.2분할 공식을 유지하고, 웹 데스크톱은 rail의 빈 공간을 줄이도록 별도 확대한다.
  - iOS `DPFriendTagSelector.cardWidth(availableWidth:spacing:minimum:maximum:)` (min 60 / max 88, `@ScaledMetric`)
  - 웹 `< 1024px`: `clamp(3.75rem, (100% - gap*3)/3.2, 5.5rem)`
  - 웹 `>= 1024px`: 같은 공식을 `clamp(7.25rem, ..., 8.5rem)` 경계와 `0.75rem` gap/padding으로 적용한다. rail과 가로 스크롤은 그대로 유지한다.
- 정렬: 가로 스택은 **top 정렬** (iOS `LazyHStack(alignment: .top)`, 웹 `align-items: flex-start`).
  팀/근무 줄 자리 확보와 함께 카드 높이가 항상 같아진다.
- 순서: 핀 친구 먼저(핀 순서), 그다음 일반 친구 — 기존 정렬 로직 그대로.
- 탭: 해당 친구 캘린더로 이동(기존 동작 유지). 별 버튼 탭은 전파 차단.

## 태그 셀렉터 변경 (D7, D8)

현재 확장 상태 순서:

```
선택 목록(조건부)  ← 첫 선택 시 삽입되며 아래를 통째로 밀어냄
검색창
rail
```

변경 후:

```
검색창
rail
선택 목록(조건부)   ← 아래쪽에서 자라남
```

- iOS `DPFriendTagSelector.expandedSelector` 에서 `selectedStrip` 을 `rail` 뒤로 이동.
- 웹 `FriendTagSelector.vue` 에서 `.friend-tag-selector__selected` 블록을 rail 뒤로 이동.
- 팀 줄: 값이 없을 때도 같은 높이를 차지하도록 항상 렌더(빈 자리, 대체 문구 없음).

## iOS 햅틱 "표준 세트" (D9)

기존 정책(`DPButtonStyles.DPButtonFeedback`, `DPDragFeedback`)을 그대로 따른다.
누름 순간에만 발생 · 비활성 컨트롤은 무음 · 되돌릴 수 있는 탭 = `impact(.soft, 0.6)` ·
파괴적 = `impact(.solid, 1.0)` · 드래그 = lift `solid 0.8` / drop `soft 0.5` · 슬롯 이동 = `.selection`.

| 대상 | 피드백 |
|---|---|
| 태그 셀렉터 카드 선택/해제, 칩 제거, 전체 해제 | `.selection` (선택) / routine (해제·제거) |
| `Toggle` 5곳 (투두 마감일, D-Day 고정, D-Day 비공개, 약관 확인, 신고-차단) | `.selection` |
| 탭바 전환 | `.selection` |
| 캘린더 날짜 선택 (본인/게스트) | `.selection` |
| 월 스와이프가 실제로 넘어가는 순간 | routine |
| 알림 스와이프 열림 / 삭제 | `.selection` / destructive |
| 당겨서 새로고침 완료 | `.success` |
| 친구 핀/언핀 (홈·친구관리) | routine |
| `FriendActionPopover` 의 친구 삭제·차단 | destructive |
| 가족 추가/해제 | routine |

새 헬퍼는 `DPButtonFeedback` 옆에 모아 두고, 화면별로 흩어진 매직 값은 만들지 않는다.

## 작업 분할

| WP | 범위 | 주요 파일 |
|---|---|---|
| WP1 | iOS 태그 셀렉터 D7·D8 | `DPFriendTagSelector.swift`, 신규 테스트 파일 |
| WP2 | 웹 태그 셀렉터 D7·D8 | `FriendTagSelector.vue`, `friendTagSelection.test.ts` 인접 |
| WP3 | iOS 홈 rail 전환 + 순서변경 제거 | `HomeView.swift`, `HomeDashboardTests`, `DragFeedbackTests`, `SocialFeatureTests`, 홈 UI 테스트 |
| WP4 | 웹 홈 rail 전환 + 순서변경 제거 | `DashboardView.vue`, `i18n/messages/{ko,en}.ts` |
| WP5 | iOS 햅틱 표준 세트 | 다수 (WP1·WP3 이후) |

WP1·WP2·WP3·WP4 는 파일이 겹치지 않아 병렬. WP5 는 WP1·WP3 이후.

## 통합 시 확정한 것

- **어느 줄도 글자를 축소하지 않는다.** `minimumScaleFactor` 는 글자와 함께 줄 박스까지 줄여서, 이름이나 팀명이 긴 카드가 이웃보다 낮아진다(실측 168.67pt vs 171.0pt). D7 "모든 카드 높이 동일" 이 우선이므로 홈 rail 과 태그 셀렉터 **양쪽 모두** 축소 대신 말줄임을 쓴다. 웹은 원래 `text-overflow: ellipsis` 라 이미 이 규칙과 같다.
- **카드 폭 경계는 한 곳에서만 정의한다.** `DPFriendTagSelectionLogic.minimumCardWidth` / `maximumCardWidth` (60 / 88) 가 유일한 출처이고, 홈 rail 은 여기서 가져다 쓴다. 폭 공식(`cardWidth`) 도 이미 공유한다.

## 알려진 선행 문제 (이 작업 소관 아님)

- `Features/Auth/AppRootView.swift` 의 `ContentFilterStore.shared.load()` 가 `-ui-testing-*` 가드보다 먼저 실행돼 `APIClient.swift` 의 `fatalError` 를 밟는다. **UI 테스트 타깃 전체가 앱 실행 즉시 크래시**한다. content-filter 세션 소유.
- `DutyparkUITests/SocialPinnedFriendReorderUITests` 2건은 커밋 8b503e20(8월 17일)부터 깨져 있다 — 회원 캘린더 식별자가 `screen.calendar` → `screen.calendar.member` 로 바뀐 것을 반영하지 않았다.

## 주의: 동시 세션

다른 세션이 `report-cancel` 작업으로 아래 파일을 수정 중이다. 건드리지 않는다.
`frontend/src/style.css`, `frontend/src/components/member/FriendActionMenu.vue`,
`ios/Dutypark/Components/DPHorizontalPan.swift`, `DPDesignTokens.swift`, `DPModalOverlay.swift`,
`RootTabView.swift`, `CalendarView.swift`, `GuestPublicCalendarView.swift`,
`frontend/src/i18n/messages/{ko,en}.ts`, report/support 전반.

WP5 가 `RootTabView.swift` · `CalendarView.swift` · `GuestPublicCalendarView.swift` 를 필요로 하므로,
WP5 착수 직전 해당 파일의 mtime 을 다시 확인한다.
