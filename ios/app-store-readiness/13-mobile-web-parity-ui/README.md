# 13. 모바일 웹 → iOS 앱 UI/UX 회귀 수정

- 기준일: 2026-08-15
- 목적: 반응형 모바일 웹(`http://localhost:5173`)을 iOS 네이티브 앱으로 이식하는 과정에서 나빠진 화면과 동작을 찾아 웹 수준으로 되돌린다.
- 기준 기기: iPhone 13 mini 시뮬레이터(`360×780pt`, iOS 26.5) / 모바일 웹 `375×812`
- 판정 원칙: 웹을 레퍼런스로 삼고, 명백히 나빠진 부분만 회귀로 판정한다.
- 관련 문서: [12. 웹 → iOS 기능·UX 동등성](../12-web-app-parity/README.md)

## 작업·보고 규칙

명확한 작업 단위마다 아래 순서를 완료한다.

1. 웹과 수정 전 iOS를 비교하고 회귀를 기록한다.
2. 수정 및 집중 테스트를 완료한다.
3. iPhone 13 mini에서 수정 후 화면과 핵심 상호작용을 확인한다.
4. 기능 커밋을 만든다.
5. 이 문서에 커밋 해시, 전·후 스크린샷, 변경 요약, 검증 결과를 즉시 반영하고 문서 커밋을 만든다.

스크린샷이나 상호작용 검증이 남은 기능 커밋은 `코드 커밋됨`으로만 기록하며 `완료`로 올리지 않는다.

## 검증 환경

| 항목 | 값 |
| --- | --- |
| 백엔드 | `http://localhost:8080` (dev, `dutypark_dev_db` MySQL) |
| 웹 | `http://localhost:5173`, viewport `375×812`, 한국어, 다크 모드 |
| 앱 | Debug UI fixture, 한국어, 다크 모드 |
| 시뮬레이터 | Outcrop iPhone 13 mini `F0737016-7654-4967-83FA-1DFB951DB36E` |
| 회귀 테스트 | 선택한 iOS 단위 테스트 전체 통과, `/tmp/dutypark-parity-main/Logs/Test/Test-Dutypark-2026.08.15_09-21-46-+0900.xcresult` |
| 시각 캡처 | `ParityVisualCaptureUITests` 1건 통과, `/tmp/Dutypark-ParityVisualCapture-20260815-10.xcresult` |

## 진행 현황

| # | 화면 | 회귀 내용 | 상태 | 관련 커밋 |
| --- | --- | --- | --- | --- |
| 1 | 대시보드 · 친구 | `친구관리`가 `친구`로 축약됨 | 완료 | `abee3186` |
| 2 | 대시보드 · 친구 | 웹에 없는 받은/보낸 요청 카운트 표시 | 완료 | `abee3186` |
| 3 | 대시보드 · 친구 | 작은 핸들 아이콘과 작동하지 않는 순서 변경 | 완료 | `abee3186` |
| 4 | Todo | 핸들 기반 순서 변경을 롱프레스 드래그로 변경 | 완료 | `a28f348c` |
| 5 | 대시보드 · 헤더 | 로고와 액션에 불필요한 캡슐 테두리 | 완료 | `74858618` |
| 6 | 하단 탭 | `달력`이 `캘린더`로 변경됨 | 완료 | `74858618` |
| 7 | 전역 현지화 | 한국어 앱에서 기본 패턴·메뉴·팀 월 이름 등이 영어로 표시됨 | 부분 완료 | `74858618`, `2cdc26ea`, `3987ea66` |
| 8 | 설정 · 기본 근무 패턴 | 근무 선택 목록과 요일 선택 UI가 웹보다 나빠짐 | 수정됨·커밋 전 | 다음 기능 커밋 |
| 9 | 전역 확인 UI | destructive 확인 UI가 터치 위치와 무관한 시스템 시트로 표시됨 | 부분 완료 | `de46f754`, `92f3fa66`, `def118e2` |
| 10 | 친구관리 상세 | 롱프레스 재정렬 적용 후 iOS 26 화면 진입 크래시 | 후속 수정 중 | `f5da2cd1` 후속 필요 |

상태는 `대기 → 진행 중 → 수정됨·커밋 전 → 코드 커밋됨·시각 검증 전 → 완료` 순으로 관리한다.

## 커밋 보고

| 커밋 | 작업 단위 | 자동 검증 | 시각 증빙 | 판정 |
| --- | --- | --- | --- | --- |
| `de46f754` | 재사용 가능한 중앙 확인 패널 | 앱 빌드, 컴포넌트 테스트 | 기본 패턴 적용 화면으로 채택 결과 확보 | 완료 |
| `abee3186` | 대시보드 친구 섹션 웹 동등성 | `HomeDashboardTests` 11건 | 웹·수정 전·수정 후 확보 | 완료 |
| `a28f348c` | Todo 롱프레스 재정렬 | `TodoViewModelTests` 포함 전체 선택 테스트 | 웹·수정 후 확보, 빈 fixture라 실제 드래그는 단위 테스트로 검증 | 완료 |
| `f5da2cd1` | 친구관리 롱프레스 재정렬 | `SocialFeatureTests` 포함 전체 선택 테스트 | 상세 화면 진입 중 크래시 발견 | 후속 수정 중 |
| `92f3fa66` | 알림 삭제 중앙 확인 | `NotificationFeatureTests` 포함 전체 선택 테스트 | 삭제 가능한 알림 fixture 부재 | 코드 커밋됨·캡처 대기 |
| `def118e2` | 첨부 삭제 중앙 확인 | `AttachmentTests` 포함 전체 선택 테스트 | 첨부 fixture 부재 | 코드 커밋됨·캡처 대기 |
| `74858618` | 헤더 캡슐 제거, `달력` 복원, Root 메뉴 현지화 | AppTab·RootChrome·컴포넌트 테스트 및 UI 캡처 | 대시보드·메뉴 수정 후 확보 | 완료 |
| `2cdc26ea` | 앱 언어 override 및 로그인·OAuth·API 오류 현지화 | 앱 언어 override·Auth 테스트 포함 전체 선택 테스트 | 한국어 메뉴·설정 화면에서 Foundation 조회 결과 확인 | 완료 |
| `3987ea66` | 팀 연월 선택기의 월 이름 현지화 | `TeamFeatureTests` 앱 ko·기기 en 조합 | 웹 기준 확보, iOS 연월 선택기 캡처 대기 | 코드 커밋됨·캡처 대기 |

## 상세 변경 보고

### 대시보드 친구 섹션 — `abee3186`

| 웹 기준 | iOS 수정 전 | iOS 수정 후 |
| --- | --- | --- |
| <img src="screenshots/dashboard-web-ko-before.png" width="240" alt="모바일 웹 대시보드"> | <img src="screenshots/dashboard-ios-before.png" width="240" alt="수정 전 iOS 대시보드"> | <img src="screenshots/dashboard-ios-after.png" width="240" alt="수정 후 iOS 대시보드"> |

- 원래 웹: 제목은 `친구관리`, 요청 카운트와 별도 재정렬 핸들이 없다.
- 수정 전 iOS: 제목이 `친구`로 축약됐고 받은/보낸 요청 카운트 및 작은 핸들을 노출했다.
- 수정 후 iOS: 제목을 복원하고 카운트와 핸들을 제거했다. 친구 카드 자체를 0.35초 이상 누르면 드래그 모드가 된다.
- 접근성: VoiceOver 위/아래 이동 액션은 유지했다.
- 검증: `HomeDashboardTests` 11건 통과, iPhone 13 mini 수정 후 화면 확인.

### Todo 롱프레스 재정렬 — `a28f348c`

| 웹 기준 | iOS 수정 후 |
| --- | --- |
| <img src="screenshots/todo-web-ko.png" width="240" alt="모바일 웹 Todo"> | <img src="screenshots/todo-ios-after.png" width="240" alt="수정 후 iOS Todo"> |

- 별도 재정렬 아이콘을 제거하고 카드 자체를 0.35초 롱프레스한 뒤 드래그하도록 통일했다.
- 일반 스크롤과 충돌하지 않도록 롱프레스 중 이동 허용 범위를 제한했다.
- 빈 UI fixture에서는 핸들 제거와 레이아웃을 확인했고, 순서 저장 정책은 집중 테스트로 검증했다.

### 친구관리 상세 롱프레스 재정렬 — `f5da2cd1`

| 웹 기준 | iOS 수정 후 |
| --- | --- |
| <img src="screenshots/friends-web-ko.png" width="240" alt="모바일 웹 친구관리"> | 캡처 대기 — 메뉴에서 친구관리 진입 시 iOS 26 SwiftUI 메타데이터 크래시 발견 |

- 코드와 단위 테스트는 커밋했지만 실기기 흐름 검증에서 크래시를 발견했다.
- 크래시 위치는 제네릭 `@ViewBuilder` 기반 재정렬 래퍼의 `DynamicPropertyCache` 경로로 좁혔다.
- 해당 래퍼를 단순화한 뒤 상세 화면 진입, 롱프레스, 드래그 저장을 재검증하고 후속 커밋과 스크린샷을 추가한다.

### 헤더·탭·한국어 메뉴 — `74858618`

| 웹 메뉴 | iOS 수정 후 대시보드 | iOS 수정 후 메뉴 |
| --- | --- | --- |
| <img src="screenshots/menu-web-ko.png" width="240" alt="모바일 웹 메뉴"> | <img src="screenshots/dashboard-ios-after.png" width="240" alt="수정 후 iOS 헤더와 탭"> | <img src="screenshots/menu-ios-after.png" width="240" alt="수정 후 iOS 메뉴"> |

- iOS 26 toolbar가 자동 적용하던 로고·액션 캡슐 배경을 숨겼다.
- 하단 탭을 `캘린더`에서 `달력`으로 되돌렸다.
- 앱 언어를 한국어로 강제하고 기기 언어를 영어로 두어도 메뉴가 `달력·팀·친구관리·할일·알림·설정`으로 표시되는 것을 확인했다.
- 관련 구현은 단위 테스트와 iPhone 13 mini 시각 캡처를 통과했다.

### 기본 근무 패턴 목록 UI — 기능 커밋 전

| 웹 패턴 편집 | 웹 근무 선택 | iOS 수정 후 |
| --- | --- | --- |
| <img src="screenshots/pattern-modal-web-ko.png" width="240" alt="모바일 웹 기본 근무 패턴"> | <img src="screenshots/pattern-duty-list-web-ko.png" width="240" alt="모바일 웹 근무 선택 목록"> | <img src="screenshots/pattern-modal-ios-after.png" width="240" alt="수정 후 iOS 기본 근무 패턴"> |

- 웹처럼 7개 요일 칩을 먼저 표시하고 선택한 요일의 근무 행만 노출한다.
- 근무 행에 색상, 이름, 선택 상태와 펼침 표시를 함께 보여준다.
- 신규 패턴은 웹과 동일하게 월~금 및 첫 근무유형을 기본값으로 사용한다.
- `적용 시작`, `패턴 해제` 등 앱 언어를 따르지 않던 문자열을 함께 교정했다.

### 앱 언어 override — `2cdc26ea`

| 한국어 메뉴 | 한국어 설정 |
| --- | --- |
| <img src="screenshots/menu-ios-after.png" width="240" alt="한국어 iOS 메뉴"> | <img src="screenshots/settings-ios-after.png" width="240" alt="한국어 iOS 설정"> |

- SwiftUI의 `locale` 환경값과 별개로 기기 언어를 따라가던 Foundation 문자열 조회를 앱에서 선택한 `.lproj` bundle로 통일했다.
- 캘린더·설정 공통 문구, API 오류, 로그인 남은 횟수, OAuth 오류가 앱 언어를 따른다.
- 알 수 없는 시스템 인증 오류의 영문 `localizedDescription`을 그대로 노출하지 않고 앱 언어의 일반 오류로 대체한다.
- 앱 언어 한국어·기기 언어 영어 조합의 회귀 테스트를 통과했다.

### 팀 월 이름 현지화 — `3987ea66`

| 웹 기준 | iOS 수정 후 |
| --- | --- |
| <img src="screenshots/team-web-ko.png" width="240" alt="모바일 웹 팀 화면"> | 연월 선택기 캡처 대기 |

- 기기 캘린더의 `monthSymbols`를 직접 사용하던 코드를 앱 locale 기반 `DateFormatter`로 교체했다.
- 앱 한국어·기기 영어에서는 `8월`, 앱 영어에서는 `August`가 되는 회귀 테스트를 통과했다.
- 팀 연월 선택기를 여는 UI fixture를 추가해 수정 후 스크린샷을 보강한다.

### 중앙 확인 UI — `de46f754` 및 후속 적용 커밋

| 웹 기준 | iOS 수정 후 |
| --- | --- |
| <img src="screenshots/pattern-delete-confirm-web-ko.png" width="240" alt="모바일 웹 패턴 삭제 확인"> | <img src="screenshots/pattern-delete-confirm-ios-after.png" width="240" alt="수정 후 iOS 패턴 해제 확인"> |

- 터치 지점이나 OS에 따라 위치가 달라지는 `confirmationDialog` 대신 화면 중앙의 공통 확인 패널을 추가했다.
- 제목, 영향 범위 설명, 취소 및 destructive 동작을 한 패널에서 명확히 보여준다.
- 기본 패턴 해제는 iPhone 13 mini UI 테스트에서 중앙 표시와 한국어 문구를 확인했다.
- 알림 삭제(`92f3fa66`)와 첨부 삭제(`def118e2`)에도 같은 패널을 적용했다. 두 화면은 삭제 대상 fixture를 추가한 뒤 별도 캡처한다.

## 시각 회귀 자동화

`ParityVisualCaptureUITests`는 한국어·다크모드로 앱을 실행해 다음 화면을 순서대로 캡처한다.

- 대시보드
- Todo
- 햄버거 메뉴
- 설정
- 기본 근무 패턴
- 패턴 해제 중앙 확인

2026-08-15 실행 결과: 1개 테스트, 실패 0건, 약 27초.

## 미해결·다음 순서

- [ ] 친구관리 상세 iOS 26 진입 크래시 수정 및 재정렬 시각 검증
- [x] 헤더·탭·Root 메뉴 현지화 기능 커밋 및 시각 보고
- [ ] 기본 근무 패턴과 캘린더 확인 UI 기능 커밋 후 문서에 커밋 해시 반영
- [ ] 알림 삭제용 UI fixture와 중앙 패널 스크린샷 추가
- [ ] 첨부 삭제용 UI fixture와 중앙 패널 스크린샷 추가
- [ ] 팀 연월 선택기 한국어 스크린샷 추가
- [ ] 설정의 사진 삭제·관리자 해제·관리 계정 전환 확인 UI 조사 및 수정
- [ ] 로그아웃 등 남은 전역 `confirmationDialog` 조사 및 수정
