# 회원 이름 길이 확대와 좁은 칸 이니셜 표시

회원 이름의 10자 제한은 영어 이름에 너무 빡빡하다. 최대 길이를 20자로 늘리고, 한글 3글자에 맞춘 좁은 칸에
긴 영문 이름이 다 들어가지 않으면 이니셜(Shane Park → S.P)로 보여준다.

## 결정 사항

| 항목 | 결정 |
| --- | --- |
| 최대 길이 | 20자. 서버·웹·iOS 모두 UTF-16 code unit 기준(Java `String.length`, JS `string.length`, Swift `utf16.count`) |
| DB | 변경 없음. `member.name`은 varchar(255), 스냅샷 칸(`schedule.created_by_name` 등)은 VARCHAR(50)이라 20자로 충분 |
| 줄임 규칙 | 공백으로 나뉜 단어가 2개 이상이고 모든 단어가 라틴 문자(`\p{Script=Latin}`)로 시작하면 각 단어 첫 글자를 대문자로 바꿔 `.`으로 잇는다. 그 밖의 이름은 이니셜이 없고, 각 화면의 기존 자르기를 그대로 쓴다 |
| 적용 범위 | 좁은 칸만: 달력 칸 태그, 여러 날 일정 띠, 홈 친구 카드, 팀 근무 카드, 친구 선택 카드. 목록·알림·프로필 같은 넓은 곳은 전체 이름 |
| 적용 조건 | 전체 이름이 칸에 들어가면 전체 이름. 넘칠 때만 이니셜, 이니셜이 없으면 기존 자르기 |
| 서버 계약 | 응답 DTO에 줄임 이름 필드를 추가하지 않는다. 줄임은 클라이언트 표시 전용 |
| 이니셜 중복 | 같은 화면에 이니셜이 같은 사람이 있어도(Shane Park, Sarah Park → S.P) 그대로 둔다. 프로필 사진으로 구분되고, 웹은 `title`, iOS는 접근성 레이블로 전체 이름을 제공한다 |
| 여러 날 일정 띠 | 칩 개수 N마다 전체 이름 → 짧은 라벨 순으로 시도하고, 둘 다 넘칠 때만 칩을 줄이고 "+N"을 붙인다(웹·iOS 동일) |

## 줄임 규칙 공통 테스트 벡터

웹 `memberInitials(name)`과 iOS `MemberNameInitials.initials(for:)`는 아래 표를 똑같이 통과해야 한다.
`null`/`nil`은 이니셜이 없다는 뜻이며, 화면은 기존 자르기를 쓴다.

| 입력 | 결과 |
| --- | --- |
| `Shane Park` | `S.P` |
| `Mary Jane Lee` | `M.J.L` |
| `shane park` | `S.P` |
| `  Shane   Park  ` | `S.P` |
| `Jean-Luc Picard` | `J.P` |
| `Élodie Durand` | `É.D` |
| `Christopher` | 없음 (단어 1개) |
| `박세현` | 없음 |
| `박 세현` | 없음 (라틴 문자가 아님) |
| `Shane 박` | 없음 (모든 단어가 라틴 문자로 시작해야 함) |
| `` (빈 문자열) | 없음 |

기존 자르기는 바꾸지 않는다. 달력 칸 태그는 3 code point를 넘으면 앞 2글자 + `…`(웹
`getCalendarTagLabel`, iOS `DPMemberTagChip` `.micro`), 카드류는 기존 말줄임(tail truncation)이다.

## 넘침 판단

- **웹:** 좁은 칸마다 전체 이름을 먼저 그리고, 실제로 넘치는지(`scrollWidth > clientWidth`)를
  `ResizeObserver`로 확인해 넘칠 때만 이니셜로 바꾸는 공용 컴포넌트(또는 composable)를 하나 만들어 쓴다.
  달력 칸 태그처럼 이미 글자 수로 판단하는 곳은, 글자 수 기준을 넘을 때 이니셜이 있으면 이니셜을, 없으면
  기존 `앞 2글자 + …`를 쓴다.
- **iOS:** `ViewThatFits`로 전체 이름 → 이니셜 순으로 시도하고, 이니셜이 없으면 기존 표시를 쓴다.
  `.micro` 태그처럼 글자 수로 판단하는 곳은 웹과 같은 글자 수 기준을 쓴다.

## 작업 단위와 파일 소유

### WP-B 백엔드 (별도 worktree)

- `Member.kt` `NAME_MAX_LENGTH = 20`. `@Column(length = ...)`이 스키마 검증에 영향을 주는지 확인
- `MemberNameLength.kt`와 `sso.username.length` 메시지(메시지 프로퍼티 전 언어)의 "10" 문구
- 관련 테스트와 REST Docs(`MemberControllerTest` 등). 11~20자 허용, 21자 거부를 테스트로 고정
- 검증: 이름 관련 Gradle 테스트 집중 실행 후 `MemberControllerTest`, SSO 가입 테스트

### WP-W 웹

- `frontend/src/utils/signupName.ts` `MEMBER_NAME_MAX_LENGTH = 20`, 새 `memberInitials` 헬퍼(같은 파일 또는
  `utils/memberName.ts`)와 위 테스트 벡터
- `SsoSignupView.vue`, `MemberView.vue`의 하드코딩 10 제거
- `en.ts`/`ko.ts`의 "10자" 문구, `public-content/guide.json`(ko·en)의 10자 언급
- 좁은 칸: `DutyCalendarContent.vue`, `CalendarSpanTags.vue`, `DashboardView.vue`, `TeamView.vue`,
  `FriendTagSelector.vue`, `MemberTagChips.vue`
- 검증: 관련 vitest, `npm run type-check`, `npm run build`, 개발 계정으로 headless Playwright 확인(라이트·다크,
  데스크톱·모바일). 개발 계정 이름을 바꿔 확인했다면 원래 이름으로 되돌린다

### WP-I iOS (내 정보 속도 개선 iOS 작업이 끝난 뒤 시작)

- `SsoSignupNamePolicy.maxLength = 20`
- `MyInfoView.swift` 보조 계정 모달의 `.count`·하드코딩 10을 `SsoSignupNamePolicy`로 교체, 이름 변경 모달 확인
- `SettingsViewModel.swift`의 이름 길이 검증
- `OAuth.xcstrings`, `Errors.xcstrings`, `Settings.xcstrings`의 "10" 문구(ko·en)
- 새 `MemberNameInitials`와 위 테스트 벡터
- 좁은 칸: `DPMemberTagChip.swift`, `DPCalendarSpanRibbon.swift`, `HomeView.swift`, `TeamView.swift`,
  `DPFriendTagSelector.swift`, `CalendarView.swift`
- 검증: 관련 `DutyparkTests` 클래스만 집중 실행. 전체 실행과 설치는 메인 에이전트가 맡는다

## i18n 소유

- 웹 `en.ts`/`ko.ts`, `public-content/guide.json`: WP-W
- iOS `*.xcstrings`: WP-I
- 백엔드 메시지 프로퍼티: WP-B

새 문구 키는 만들지 않는다. 기존 문구의 숫자만 20으로 바꾼다.

## 범위 밖

- 회원이 직접 정하는 줄임 이름
- 넓은 화면(목록·알림·프로필)의 표시 변경
- 위젯(이름을 표시하지 않음)
