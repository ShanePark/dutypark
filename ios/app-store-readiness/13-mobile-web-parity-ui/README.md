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
| 시각 캡처 | `ParityVisualCaptureUITests` 1건 통과, `/tmp/Dutypark-ParityVisualCapture-20260815-11.xcresult` |

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
| 8 | 설정 · 기본 근무 패턴 | 근무 선택 목록과 요일 선택 UI가 웹보다 나빠짐 | 완료 | `b7bdc8ae` |
| 9 | 전역 확인 UI | destructive 확인 UI가 터치 위치와 무관한 시스템 시트로 표시됨 | 부분 완료 | `de46f754`, `92f3fa66`, `def118e2`, `b7bdc8ae`, `2316075a`, `84047661`, `bd3a1fc4`, `2ecdbb70`, `8a6a3aae`, `a19f4047`, `cc673095`, `38dc5bca` |
| 10 | 친구관리 상세 | UI 테스트에서 실 API를 호출해 화면 진입 종료 | 완료 | `f5da2cd1`, `24814f20` |
| 11 | 친구관리 상세 | 존재하지 않는 SF Symbol로 `더보기` 버튼이 0×0이고 터치 불가 | 완료 | `38dc5bca` |
| 12 | 달력 · 월 일괄 변경 | 한국어 연도가 `2,026년`으로 숫자 그룹화됨 | 완료 | `c47a77ea` |

상태는 `대기 → 진행 중 → 수정됨·커밋 전 → 코드 커밋됨·시각 검증 전 → 완료` 순으로 관리한다.

## 커밋 보고

| 커밋 | 작업 단위 | 자동 검증 | 시각 증빙 | 판정 |
| --- | --- | --- | --- | --- |
| `de46f754` | 재사용 가능한 중앙 확인 패널 | 앱 빌드, 컴포넌트 테스트 | 기본 패턴 적용 화면으로 채택 결과 확보 | 완료 |
| `abee3186` | 대시보드 친구 섹션 웹 동등성 | `HomeDashboardTests` 11건 | 웹·수정 전·수정 후 확보 | 완료 |
| `a28f348c` | Todo 롱프레스 재정렬 | `TodoViewModelTests` 포함 전체 선택 테스트 | 웹·수정 후 확보, 빈 fixture라 실제 드래그는 단위 테스트로 검증 | 완료 |
| `f5da2cd1` | 친구관리 롱프레스 재정렬 | `SocialFeatureTests` 포함 전체 선택 테스트 | 후속 UI 검증에서 fixture 결함 발견 | `24814f20`으로 보완 |
| `92f3fa66` | 알림 삭제 중앙 확인 | `NotificationFeatureTests` 포함 전체 선택 테스트 | `da97937c`에서 개별·일괄 삭제 캡처 확보 | 완료 |
| `def118e2` | 첨부 삭제 중앙 확인 | `AttachmentTests` 포함 전체 선택 테스트 | `28bfcbed`에서 실제 메뉴 경로 캡처 확보 | 완료 |
| `74858618` | 헤더 캡슐 제거, `달력` 복원, Root 메뉴 현지화 | AppTab·RootChrome·컴포넌트 테스트 및 UI 캡처 | 대시보드·메뉴 수정 후 확보 | 완료 |
| `2cdc26ea` | 앱 언어 override 및 로그인·OAuth·API 오류 현지화 | 앱 언어 override·Auth 테스트 포함 전체 선택 테스트 | 한국어 메뉴·설정 화면에서 Foundation 조회 결과 확인 | 완료 |
| `3987ea66` | 팀 연월 선택기의 월 이름 현지화 | `TeamFeatureTests` 앱 ko·기기 en 조합 | `d444f095`에서 1~12월 한국어 캡처 확보 | 완료 |
| `b7bdc8ae` | 기본 근무 패턴 UI 및 캘린더 중앙 확인 흐름 | Settings·Calendar 테스트 및 UI 캡처 | 패턴 편집·해제 확인 확보, 월 일괄 변경 캡처 대기 | 패턴 완료·캘린더 캡처 대기 |
| `24814f20` | 친구관리 UI fixture 안정화 및 실제 롱프레스 재정렬 | iPhone 13 mini 전용 UI 테스트 1건 | 친구관리 수정 후 화면 확보 | 완료 |
| `2316075a` | 관리자 팀 삭제·회원 세션 종료 중앙 확인 | AdminTeam·AdminFeature 테스트 포함 전체 선택 테스트 | `eee695a9`에서 두 패널 캡처 확보 | 완료 |
| `84047661` | 설정의 계정·프로필 destructive 확인 5종 | iPhone 13 mini `SettingsFeatureTests` 29건 | 설정 화면 확보, 확인 패널 직접 캡처 대기 | 코드 커밋됨·패널 캡처 대기 |
| `bd3a1fc4` | Todo 작성 취소·삭제·태그 해제 중앙 확인 | iPhone 13 mini 단위 32건·UI 1건 | Todo 화면 확보, 확인 패널 직접 캡처 대기 | 코드·상호작용 완료·캡처 대기 |
| `2ecdbb70` | 팀 일정 삭제 및 팀 관리 확인 UI | iPhone 13 mini `TeamFeatureTests` 24건 | `d444f095`에서 가입 팀 패널 2종 확보 | 완료 |
| `8a6a3aae` | Root 햄버거 로그아웃 중앙 확인 | iPhone 13 mini 전용 테스트 3건 | 메뉴 화면 확보, 패널 직접 캡처 대기 | 코드·테스트 완료·캡처 대기 |
| `a19f4047` | 소셜 계정 연결 해제 중앙 확인 | iPhone 13 mini 전용 테스트 3건 | `8c947a62`에서 관리·확인 패널 캡처 확보 | 완료 |
| `cc673095` | SSO 추가정보 draft 폐기 중앙 확인 | iPhone 13 mini OAuth 가입 테스트 6건 | `eb822f5e`에서 직접 진입 캡처 확보 | 완료 |
| `38dc5bca` | 친구 destructive 확인 4종 및 `더보기` 터치 복원 | Social 19건·재정렬 UI·삭제 패널 UI | 친구 삭제 중앙 패널 확보 | 완료 |
| `c47a77ea` | 달력 연도 치환의 천 단위 구분 제거 | 앱·테스트 빌드, exact 한국어 문자열 회귀 테스트 | 수정 후 월 일괄 변경 화면 재캡처 | 완료 |
| `f390c6bc` | 달력 월 일괄 변경 시각 fixture | iPhone 13 mini UI 1건 | 중앙 선택 패널·`2026년` 표기 확보 | 완료 |
| `22d0bc18` | 설정·Root 확인 패널 시각 fixture | iPhone 13 mini UI 3건 및 안정화 재캡처 1건 | 프로필 삭제·설정 로그아웃·메뉴 로그아웃 확보 | 완료 |
| `da97937c` | 알림 삭제 확인 시각 fixture와 전환 안정성 검증 | iPhone 13 mini UI 2건 | 개별·읽은 알림 일괄 삭제 패널 확보 | 완료 |
| `3bef215b` | DEBUG 전용 direct visual fixture 라우트 | Debug·Release 빌드 및 route 정책 테스트 | 첨부·SSO·관리자 캡처 경로 제공 | 완료 |
| `28bfcbed` | 첨부 삭제 확인 시각 검증 | iPhone 13 mini UI 1건 | 메뉴→삭제 중앙 패널 확보 | 완료 |
| `d444f095` | 가입 팀 달력·관리 시각 fixture | iPhone 13 mini UI 3건 | 연월 선택·일정 삭제·구성원 제외 확보 | 완료 |
| `aaca282c` | 긴 확인 문구의 취소·확인 버튼 겹침 방지 | 공통 패널 계약·generic test build | 관리자 세션 종료에서 픽셀 재검증 | 완료 |
| `eee695a9` | 관리자 destructive 확인 시각 fixture | iPhone 13 mini UI 2건 | 팀 삭제·회원 세션 종료 확보 | 완료 |
| `8c947a62` | 소셜 연결 관리 시각 fixture | iPhone 13 mini UI 1건 | Kakao 관리·연결 해제 패널 확보 | 완료 |
| `eb822f5e` | SSO 추가정보 draft 폐기 시각 검증 | iPhone 13 mini UI 1건 | 작성 내용 폐기 중앙 패널 확보 | 완료 |

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

### 친구관리 상세 롱프레스 재정렬 — `f5da2cd1`, `24814f20`

| 웹 기준 | iOS 수정 후 |
| --- | --- |
| <img src="screenshots/friends-web-ko.png" width="240" alt="모바일 웹 친구관리"> | <img src="screenshots/friends-ios-after.png" width="240" alt="수정 후 iOS 친구관리"> |

- 최초 크래시처럼 보인 현상은 인증 UI 테스트 fixture가 친구 API를 실호출해 `APIClient`의 보호용 `fatalError`에 도달한 것이 원인이었다.
- 친구 3명 fixture와 네트워크 없는 로컬 순서 저장 경로를 추가하고 제네릭 재정렬 래퍼를 단순화했다.
- iPhone 13 mini에서 햄버거 → 친구관리 진입 → 첫 카드를 0.5초 롱프레스 → 두 번째 카드로 드래그 → 실제 y 순서 역전까지 검증했다.
- 결과: 1개 UI 테스트, 실패 0건, `/tmp/Dutypark-SocialParity-20260815-01.xcresult`.

### 헤더·탭·한국어 메뉴 — `74858618`

| 웹 메뉴 | iOS 수정 후 대시보드 | iOS 수정 후 메뉴 |
| --- | --- | --- |
| <img src="screenshots/menu-web-ko.png" width="240" alt="모바일 웹 메뉴"> | <img src="screenshots/dashboard-ios-after.png" width="240" alt="수정 후 iOS 헤더와 탭"> | <img src="screenshots/menu-ios-after.png" width="240" alt="수정 후 iOS 메뉴"> |

- iOS 26 toolbar가 자동 적용하던 로고·액션 캡슐 배경을 숨겼다.
- 하단 탭을 `캘린더`에서 `달력`으로 되돌렸다.
- 앱 언어를 한국어로 강제하고 기기 언어를 영어로 두어도 메뉴가 `달력·팀·친구관리·할일·알림·설정`으로 표시되는 것을 확인했다.
- 관련 구현은 단위 테스트와 iPhone 13 mini 시각 캡처를 통과했다.

### 기본 근무 패턴 목록 UI — `b7bdc8ae`

| 웹 패턴 편집 | 웹 근무 선택 | iOS 수정 후 |
| --- | --- | --- |
| <img src="screenshots/pattern-modal-web-ko.png" width="240" alt="모바일 웹 기본 근무 패턴"> | <img src="screenshots/pattern-duty-list-web-ko.png" width="240" alt="모바일 웹 근무 선택 목록"> | <img src="screenshots/pattern-modal-ios-after.png" width="240" alt="수정 후 iOS 기본 근무 패턴"> |

- 웹처럼 7개 요일 칩을 먼저 표시하고 선택한 요일의 근무 행만 노출한다.
- 근무 행에 색상, 이름, 선택 상태와 펼침 표시를 함께 보여준다.
- 신규 패턴은 웹과 동일하게 월~금 및 첫 근무유형을 기본값으로 사용한다.
- `적용 시작`, `패턴 해제` 등 앱 언어를 따르지 않던 문자열을 함께 교정했다.
- 패턴 저장·해제는 공통 중앙 확인 패널을 사용하며 iPhone 13 mini UI 캡처를 통과했다.

### 앱 언어 override — `2cdc26ea`

| 한국어 메뉴 | 한국어 설정 |
| --- | --- |
| <img src="screenshots/menu-ios-after.png" width="240" alt="한국어 iOS 메뉴"> | <img src="screenshots/settings-ios-after.png" width="240" alt="한국어 iOS 설정"> |

- SwiftUI의 `locale` 환경값과 별개로 기기 언어를 따라가던 Foundation 문자열 조회를 앱에서 선택한 `.lproj` bundle로 통일했다.
- 캘린더·설정 공통 문구, API 오류, 로그인 남은 횟수, OAuth 오류가 앱 언어를 따른다.
- 알 수 없는 시스템 인증 오류의 영문 `localizedDescription`을 그대로 노출하지 않고 앱 언어의 일반 오류로 대체한다.
- 앱 언어 한국어·기기 언어 영어 조합의 회귀 테스트를 통과했다.

### 팀 월 이름 현지화 — `3987ea66`

| 웹 기준 | iOS 수정 후 연월 선택 |
| --- | --- |
| <img src="screenshots/team-web-ko.png" width="240" alt="모바일 웹 팀 화면"> | <img src="screenshots/team-month-picker-ios-after.png" width="240" alt="iOS 팀 연월 선택기"> |

- 기기 캘린더의 `monthSymbols`를 직접 사용하던 코드를 앱 locale 기반 `DateFormatter`로 교체했다.
- 앱 한국어·기기 영어에서는 `8월`, 앱 영어에서는 `August`가 되는 회귀 테스트를 통과했다.
- 가입 팀 fixture에서 연월 선택기를 열어 `1월`부터 `12월`, 선택된 `8월`, `이번 달`을 직접 확인했다.

### 달력·팀 비교 기준 확장 — `58cbf120`

| 화면 | 모바일 웹 | iOS |
| --- | --- | --- |
| 달력 | <img src="screenshots/calendar-web-ko.png" width="240" alt="모바일 웹 달력"> | <img src="screenshots/calendar-ios-after.png" width="240" alt="iOS 달력"> |
| 팀 | <img src="screenshots/team-web-ko.png" width="240" alt="모바일 웹 팀"> | <img src="screenshots/team-ios-after.png" width="240" alt="iOS 팀"> |

- 달력은 웹과 iOS fixture의 일정·D-Day 데이터가 달라 데이터 개수는 판정에서 제외하고 월 그리드와 네비게이션 기준으로 보존한다.
- 팀은 웹이 가입 팀, iOS가 미가입 fixture라 현재 직접 비교할 수 없다. 같은 팀 fixture를 제공한 뒤 연월 선택기와 팀 일정 UI를 판정한다.
- 확장 캡처는 홈·Todo·달력·팀·메뉴·설정·패턴 편집·패턴 해제 확인 8개 화면을 한 흐름에서 검증한다.

### 중앙 확인 UI — `de46f754`, `b7bdc8ae` 및 후속 적용 커밋

| 웹 기준 | iOS 수정 후 |
| --- | --- |
| <img src="screenshots/pattern-delete-confirm-web-ko.png" width="240" alt="모바일 웹 패턴 삭제 확인"> | <img src="screenshots/pattern-delete-confirm-ios-after.png" width="240" alt="수정 후 iOS 패턴 해제 확인"> |

- 터치 지점이나 OS에 따라 위치가 달라지는 `confirmationDialog` 대신 화면 중앙의 공통 확인 패널을 추가했다.
- 제목, 영향 범위 설명, 취소 및 destructive 동작을 한 패널에서 명확히 보여준다.
- 기본 패턴 해제는 iPhone 13 mini UI 테스트에서 중앙 표시와 한국어 문구를 확인했다.
- 알림 삭제(`92f3fa66`)와 첨부 삭제(`def118e2`)에도 같은 패널을 적용했다. 두 화면은 삭제 대상 fixture를 추가한 뒤 별도 캡처한다.
- 관리자 팀 삭제와 회원 세션 종료(`2316075a`)도 중앙 패널로 통일했다. 진행 중에는 취소·외부 닫기·중복 제출을 막고, 세션 종료 패널에는 회원·기기·브라우저·IP 범위를 표시한다.

### 관리자 팀 삭제·회원 세션 종료 — `2316075a`, `aaca282c`, `eee695a9`

| 관리자 팀 삭제 | 회원 세션 종료 |
| --- | --- |
| <img src="screenshots/admin-team-delete-confirmation-ios-after.png" width="240" alt="iOS 관리자 팀 삭제 확인"> | <img src="screenshots/admin-session-revoke-confirmation-ios-after.png" width="240" alt="iOS 관리자 회원 세션 종료 확인"> |

- DEBUG 관리자 fixture로 회원이 있는 팀 삭제와 iPhone 세션 종료 경로를 직접 열었다.
- 최초 세션 종료 캡처에서 긴 확인 문구가 취소 버튼 영역을 침범해, 접근성 트리에는 존재하지만 실제 픽셀에서 `취소`가 가려지는 공통 회귀를 발견했다.
- 공통 패널의 label뿐 아니라 Button 자체에도 균등 폭을 강제해 취소·확인 버튼의 동일 폭과 간격을 복원했다.
- 강화한 `isHittable`·비중첩·동일폭 assertion과 crop 육안 검수까지 통과했다.
- iPhone 13 mini UI 테스트 2/2 통과: `/tmp/Dutypark-AdminConfirmationVisual-Final-20260815.xcresult`.

### 알림 삭제 확인 — `92f3fa66`, `da97937c`

| 개별 알림 삭제 | 읽은 알림 일괄 삭제 |
| --- | --- |
| <img src="screenshots/notification-delete-confirmation-ios-after.png" width="240" alt="iOS 개별 알림 삭제 확인"> | <img src="screenshots/notification-read-delete-confirmation-ios-after.png" width="240" alt="iOS 읽은 알림 일괄 삭제 확인"> |

- 읽은 알림 1건과 안 읽은 알림 1건을 제공하는 DEBUG 전용 fixture로 두 destructive 경로를 검증했다.
- 첫 캡처에서는 한 테스트 안에서 첫 cover를 닫자마자 두 번째 cover를 열어 전환 중간 프레임이 저장되는 문제를 발견했다.
- 두 흐름을 각각 새 앱 launch로 분리하고, 제목·본문·버튼 문구, 44pt 터치 영역, 비중첩, 화면 bounds와 4회 연속 프레임 안정성을 통과한 뒤 캡처한다.
- iPhone 13 mini UI 테스트 2/2 통과: `/tmp/Dutypark-NotificationVisualStability-20260815.xcresult`.

### 첨부파일 삭제 확인 — `def118e2`, `3bef215b`, `28bfcbed`

<img src="screenshots/attachment-delete-confirmation-ios-after.png" width="240" alt="iOS 첨부파일 삭제 중앙 확인">

- 고정 PDF fixture에서 카드의 더보기 메뉴를 열고 삭제를 선택하는 실제 경로를 검증했다.
- 패널은 대상 파일명, 취소·삭제 버튼을 같은 폭으로 표시하며 화면 중앙에 배치된다.
- direct route와 fixture는 `#if DEBUG`로 한정했고 Release 빌드에서도 제거된 상태로 컴파일되는 것을 확인했다.
- iPhone 13 mini UI 테스트 1/1 통과: `/tmp/Dutypark-AttachmentVisual-20260815-04.xcresult`.

### 설정 계정·프로필 확인 — `84047661`

| 웹 설정 기준 | 프로필 사진 삭제 | 설정 로그아웃 |
| --- | --- | --- |
| <img src="screenshots/settings-web-ko.png" width="240" alt="모바일 웹 설정"> | <img src="screenshots/profile-photo-delete-confirmation-ios-after.png" width="240" alt="iOS 프로필 사진 삭제 확인"> | <img src="screenshots/settings-logout-confirmation-ios-after.png" width="240" alt="iOS 설정 로그아웃 확인"> |

- 프로필 사진 삭제, 로그아웃, 관리자 해제, 관리 계정 전환, 세션 종료를 공통 중앙 패널로 통일했다.
- 세션 종료는 웹처럼 기기·브라우저·IP를 영향 범위에 포함한다.
- 작업 중에는 중복 실행과 배경·gesture dismiss를 차단한다.
- iPhone 13 mini에서 `SettingsFeatureTests` 29건과 전용 시각 UI 테스트 3건이 통과했다.
- `22d0bc18`에서 프로필 사진 fixture와 안정적인 접근성 식별자를 추가했고, 두 확인 패널의 제목·설명·취소·destructive 버튼 및 중앙 배치를 직접 확인했다.

### Todo destructive 확인 — `bd3a1fc4`

| 웹 Todo | iOS Todo |
| --- | --- |
| <img src="screenshots/todo-web-ko.png" width="240" alt="모바일 웹 Todo"> | <img src="screenshots/todo-ios-after.png" width="240" alt="iOS Todo"> |

- 작성·수정 변경사항 폐기, Todo 삭제, 내 태그 해제를 중앙 확인 패널로 통일했다.
- 삭제 시 첨부파일도 함께 삭제되고, 태그 해제 시 보드에서 제거된다는 영향 안내는 유지했다.
- iPhone 13 mini에서 `TodoViewModelTests` 32건과 작성 취소 중앙 패널 UI 테스트 1건이 통과했다.
- 결과: `/tmp/dutypark-todo-confirmation-unit-suite.xcresult`, `/tmp/dutypark-todo-confirmation-ui.xcresult`.

### 팀 일정·관리 확인 — `2ecdbb70`

| 웹 팀 기준 | 일정 삭제 | 구성원 제외 |
| --- | --- | --- |
| <img src="screenshots/team-web-ko.png" width="240" alt="모바일 웹 팀"> | <img src="screenshots/team-schedule-delete-confirmation-ios-after.png" width="240" alt="iOS 팀 일정 삭제 확인"> | <img src="screenshots/team-member-remove-confirmation-ios-after.png" width="240" alt="iOS 팀 구성원 제외 확인"> |

- 팀 일정 삭제에 일정 제목과 복구 불가 영향을 표시하고 중앙 패널로 통일했다.
- 멤버 제외, 권한 변경, 관리자 위임·초기화, 멤버 추가, 근무유형·업로드 변경사항 폐기도 같은 패턴을 사용한다.
- iPhone 13 mini에서 `TeamFeatureTests` 24건이 모두 통과했다.
- `d444f095`의 가입 팀 fixture에서 실제 일정 삭제와 팀 관리 구성원 제외 패널을 캡처했다.
- 제목·대상·영향 문구·버튼 중앙 배치를 확인하고, 취소 후 패널 소멸과 앱 foreground 유지까지 검증했다.
- iPhone 13 mini UI 테스트 3/3 통과: `/tmp/Dutypark-TeamParityVisual-20260815-03.xcresult`.

### Root 로그아웃 확인 — `8a6a3aae`

| 로그아웃 진입점 | 중앙 확인 패널 |
| --- | --- |
| <img src="screenshots/menu-ios-after.png" width="240" alt="iOS 햄버거 메뉴 로그아웃 진입점"> | <img src="screenshots/root-menu-logout-confirmation-ios-after.png" width="240" alt="iOS 햄버거 메뉴 로그아웃 확인"> |

- 햄버거 메뉴의 로그아웃 native `confirmationDialog`를 중앙 패널로 교체했다.
- 로그아웃 처리 중에는 재실행, 취소, 배경 탭, gesture dismiss를 차단한다.
- 링크 미지원 같은 정보 alert는 기존 방식으로 유지했다.
- iPhone 13 mini에서 전용 정책·소스 테스트 3건이 통과했다: `/tmp/dutypark-root-logout-20260815.xcresult`.
- `22d0bc18`의 전용 UI 테스트에서 실제 메뉴 진입 후 패널 중앙 배치와 한국어 버튼을 검증했으며, 전환 안정화 후 최종 스크린샷을 보존했다.

### 달력 월 일괄 변경 — `c47a77ea`, `f390c6bc`

| 모바일 웹 달력 기준 | iOS 월 일괄 변경 중앙 선택 |
| --- | --- |
| <img src="screenshots/calendar-web-ko.png" width="240" alt="모바일 웹 달력"> | <img src="screenshots/calendar-batch-selection-ios-after.png" width="240" alt="iOS 월 일괄 변경 중앙 선택"> |

- 빠른 근무 편집에서 월 일괄 변경을 열어 주간·야간 선택, 덮어쓰기 경고, 취소 동작을 한 중앙 패널에서 확인했다.
- 최초 시각 검수에서 `String(format:locale:)`가 연도 `%d`를 `2,026`으로 그룹화하는 새 회귀를 발견했다.
- 번역 bundle은 앱 언어를 유지하고 캘린더 식별자·카운트 치환에는 `en_US_POSIX`를 사용해 `2026년 8월`로 복원했다.
- 수정 후 iPhone 13 mini UI 테스트 1건이 통과했고 `2026년 8월 전체에 적용할 근무를 선택하세요.`를 육안 확인했다: `/tmp/Dutypark-CalendarBatchVisual-YearFix-20260815.xcresult`.

### 소셜 계정 연결 해제 — `a19f4047`

| 연결 관리 | 연결 해제 중앙 확인 |
| --- | --- |
| <img src="screenshots/social-connection-management-ios-after.png" width="240" alt="iOS 소셜 연결 관리"> | <img src="screenshots/social-unlink-confirmation-ios-after.png" width="240" alt="iOS 소셜 연결 해제 확인"> |

- 카카오·Google·Apple 연결 해제 native alert를 공통 중앙 패널로 교체했다.
- 처리 중에는 확인·취소·배경 탭·VoiceOver dismiss와 중복 제출을 차단한다.
- 연결 해제 오류 notice는 정보 alert로 유지했다.
- iPhone 13 mini에서 전용 테스트 3건이 통과했다: `/tmp/Dutypark-SocialConnectionManagementTests.xcresult`.
- `8c947a62`의 DEBUG fixture로 Kakao 연결 상태, 내부 연결만 해제된다는 영향 안내, 취소·연결 해제 버튼을 직접 검증했다.
- 시각 UI 테스트 1/1 통과: `/tmp/Dutypark-SocialConnectionVisual-20260815.xcresult`.

### SSO 추가정보 draft 폐기 — `cc673095`

<img src="screenshots/sso-signup-discard-confirmation-ios-after.png" width="240" alt="iOS SSO 회원가입 draft 폐기 확인">

- 작성 중인 추가정보를 취소할 때 표시되던 native alert를 중앙 패널로 교체했다.
- 빈 draft는 즉시 닫고, 작성 내용이나 약관 선택이 있을 때만 확인한다.
- 처리 중에는 중복 제출·취소·배경·gesture dismiss를 차단한다.
- iPhone 13 mini에서 OAuth 가입 프레젠테이션 테스트 6건이 통과했다: `/tmp/Dutypark-SsoSignupConfirmation-20260815-01.xcresult`.
- DEBUG direct route에서 이름 draft를 입력한 뒤 취소해 정확한 제목·영향 문구·`계속 작성`·`나가기` 버튼을 검증했다.
- 시각 UI 테스트 1/1 통과: `/tmp/Dutypark-SsoSignupVisual-20260815-02.xcresult`.

### 친구 destructive 확인과 관리 액션 — `38dc5bca`

| 친구 목록 | 친구 삭제 중앙 확인 |
| --- | --- |
| <img src="screenshots/friends-ios-after.png" width="240" alt="iOS 친구 목록"> | <img src="screenshots/friend-delete-confirmation-ios-after.png" width="240" alt="iOS 친구 삭제 중앙 확인"> |

- 친구 요청 거절·보낸 요청 취소·가족 관계 해제·친구 삭제를 중앙 패널로 통일했다.
- `ellipsis.vertical`이 iOS 26.5에 없는 SF Symbol이라 버튼 frame이 `(inf, inf, 0, 0)`이 되던 원인을 찾아, 유효한 `ellipsis`를 90도 회전해 세로 점 모양과 44pt 터치 영역을 복원했다.
- 카드 본문 캘린더 열기, 별표, 더보기, 0.35초 롱프레스 재정렬 영역을 분리했다.
- `SocialFeatureTests` 19건, 친구 진입·재정렬 UI, 친구 삭제 중앙 패널 UI가 모두 통과했다.
- 결과: `/tmp/dutypark-social-hit-symbol-20260815-1020.xcresult`, `/tmp/dutypark-social-reorder-20260815-1021.xcresult`.

## 시각 회귀 자동화

`ParityVisualCaptureUITests`는 한국어·다크모드로 앱을 실행해 다음 화면을 순서대로 캡처한다.

- 대시보드
- Todo
- 달력
- 팀
- 햄버거 메뉴
- 설정
- 기본 근무 패턴
- 패턴 해제 중앙 확인

2026-08-15 실행 결과: 1개 테스트, 실패 0건, 약 36.6초.

## 미해결·다음 순서

- [x] 친구관리 상세 진입과 롱프레스 재정렬 시각·상호작용 검증
- [x] 헤더·탭·Root 메뉴 현지화 기능 커밋 및 시각 보고
- [x] 기본 근무 패턴 UI와 패턴 해제 중앙 확인 기능 커밋 및 시각 보고
- [x] 캘린더 월 일괄 변경 중앙 선택 화면 스크린샷 추가
- [x] 알림 삭제용 UI fixture와 중앙 패널 스크린샷 추가
- [x] 첨부 삭제용 UI fixture와 중앙 패널 스크린샷 추가
- [x] 관리자 팀 삭제·회원 세션 종료 UI fixture와 중앙 패널 스크린샷 추가
- [x] 설정 로그아웃·프로필 삭제 중앙 패널 스크린샷 추가
- [ ] Todo 작성 취소·삭제 중앙 패널 스크린샷 추가
- [x] 팀 연월 선택기 한국어 스크린샷 추가
- [x] 가입 팀 fixture로 일정 삭제·관리 중앙 패널 스크린샷 추가
- [x] Root 햄버거 로그아웃 중앙 패널 스크린샷 추가
- [x] 소셜 연결 관리 fixture와 연결 해제 중앙 패널 스크린샷 추가
- [x] SSO 추가정보 fixture와 draft 폐기 중앙 패널 스크린샷 추가
- [x] 설정의 사진 삭제·관리자 해제·관리 계정 전환 확인 UI 조사 및 수정
- [x] 로그아웃 등 남은 전역 `confirmationDialog` 조사 및 수정
