# 금지 콘텐츠 필터 (Content filter)

App Store Guideline 1.2가 요구하는 "a method for filtering objectionable material from being posted"을
충족하기 위한 최소 구현. 기존 신고·차단·문의는 이미 충족되어 있으므로 이 문서는 필터만 다룬다.

## 결정 사항

| 항목 | 결정 |
| --- | --- |
| 적용 범위 | 신고 대상 3종(SCHEDULE / TODO / MEMBER)에 대응하는 사용자 입력 텍스트와 D-Day 제목·근무유형 이름. D-Day는 공개 제목만 차단하고 private 제목은 허용한다 |
| 검증 위치 | backend·iOS·웹은 code point/scalar 기준 NFKC·lowercase·Unicode letter 및 decimal digit(`Nd`) 정규화와 private D-Day 예외를 반영했다. 런타임별 contextual lowercase 차이와 웹 cold-start/fetch 실패 fail-open은 잔여 위험이며, 서버는 공개 D-Day와 근무유형/기본 근무유형 mutation 경계에서 검증한다 |
| 차단 방식 | 저장 시도 시 검사해 저장을 중단하고 안내 메시지 표시 |
| 알림 시점 | 저장/등록 버튼을 눌렀을 때. 입력 중 실시간 검사는 하지 않는다 |
| 목록 위치 | backend JSON, iOS 번들 JSON·emergencyWords fallback, 웹의 API 캐시가 각각 존재한다. 자동 동기화가 없는 중복 소스임을 전제로 관리한다 |
| 첨부파일 | 이번 범위 제외. 기존 신고 기반 대응 유지 |

클라이언트 사전 검증은 즉시 안내하는 UX를 담당하고, 서버 경계 검증은 클라이언트·직접 API 호출 우회를
방어한다. 현재 서버 경계 검증은 D-Day 공개 제목과 팀 근무유형/기본 근무유형 이름에 적용되며,
private D-Day 제목은 의도적으로 검증하지 않는다. 개인 일정·팀 일정·TODO·회원 이름 입력은 각 클라이언트에서
게시 전에 검사한다. backend·iOS·웹은 code point/scalar를 순회해 NFKC, lowercase, Unicode
letter 및 decimal digit만 남기는 같은 규칙을 구현했고 private D-Day 예외도 반영했다. 다만 런타임의
contextual lowercase 결과는 모든 Unicode script에서 byte-for-byte 동일하다고 보장하지 않는다.
다만 웹은 cold-start에서 캐시가 없거나 fetch가 실패하면 빈 목록으로 남아 client check가 fail-open되는
잔여 과제가 있다.

## 적용 대상 필드

| 신고 대상 | 필드 | 웹 | iOS |
| --- | --- | --- | --- |
| SCHEDULE | 개인 일정 `content`, `description` | `DayDetailModal.vue` | `CalendarViewModel.swift` |
| SCHEDULE | 팀 일정 `content`, `description` | `TeamView.vue` | `TeamViewModel.swift` |
| TODO | `title`, `content` | `TodoBoardView.vue`, `DutyView.vue` | `TodoViewModel.swift` |
| MEMBER | 회원가입 이름 | `SsoSignupView.vue` | `SsoSignupView.swift` |
| MEMBER | 보조계정 이름 | `MemberView.vue` | `SettingsViewModel.swift` |
| D-DAY | 공개 제목 `title` (private는 허용) | `DutyView.vue` (private 예외 반영 완료) | `CalendarViewModel.swift` |
| DUTY TYPE | 근무유형/기본 근무유형 이름 `name` | `DutyTypeModal.vue` | `TeamViewModel.swift` (`TeamManageViewModel`) |

범위 밖: 첨부파일, 팀 이름/설명(관리자 전용 생성이라 일반 UGC가 아님).
회원 본인 이름 변경 기능은 존재하지 않으므로 MEMBER는 위 두 입력이 전부다.

## API 계약 (백엔드·클라이언트 공통 규칙)

기존 `publiccontent` 모듈을 재사용한다. 새 패키지를 만들지 않는다.

```
GET /api/public-content/banned-words
```

- 인증 불필요(회원가입 화면에서도 필요하므로 공개).
- 200 OK

```json
{
  "schemaVersion": 1,
  "contentVersion": "<리소스 파일 SHA-256>",
  "words": ["...", "..."]
}
```

- `Cache-Control: no-cache, public, must-revalidate` + `ETag: banned-words-<contentVersion>` — 가이드/릴리스 노트와 동일한 방식.
- backend runtime input은 `src/main/resources/public-content/banned-words.json`
  (`{ "schemaVersion": 1, "words": [...] }`)이다. backend는 기동 시 이 파일을 로드·검증하며, 검증 실패는
  기동 실패로 만든다. 이 검증이 iOS 번들 사본이나 emergencyWords와의 동일성을 보장하지는 않는다.
- D-Day 공개 제목과 근무유형/기본 근무유형 이름을 저장하는 mutation은 서버에서도 동일 필터로 검증한다.
  private D-Day 제목은 이 서버 검증 대상이 아니며 허용한다. 차단 시 HTTP 400 response의 `code` 값은
  `contentFilter.blocked`이고, 클라이언트는 공통 필터 오류로 표시한다.

## 매칭 규칙 (backend·iOS·웹 공통 의도; 런타임 parity 잔여)

이 규칙은 grapheme/문자열 요소가 아니라 Unicode code point(iOS에서는 이에 대응하는 scalar)를 순회해
적용한다. backend·iOS·웹은 아래 공통 규칙을 구현한다. 현재 46개 목록은 영어·한국어로
구성되어 있지만, JVM/JavaScript/Swift의 contextual lowercase가 그리스어 final sigma 같은 문자에서
다른 결과를 낼 수 있으므로 새 script의 금칙어를 추가할 때는 cross-runtime fixture로 parity를 검증한다.
이와 별개로 웹의 캐시·폴백 중 cold-start/fetch 실패 fail-open이 아직 남아 있다.

1. 입력 문자열을 NFKC 정규화한다.
2. 소문자로 바꾼다.
3. 유니코드 letter / decimal digit(`Nd`) 이외의 모든 문자를 제거한다
   (서버 `Character.isLetterOrDigit`, 웹 `/[^\p{L}\p{Nd}]/gu`,
   iOS 유니코드 스칼라 general category `L*` + `decimalNumber`.
   iOS의 `Character.isLetter`/`isNumber`는 `Nl`·`No`까지 포함해 셋이 어긋나므로 쓰지 않는다).
   `ㅅ.ㅂ`, `f u c k` 같은 단순 우회를 흡수하기 위함이다.
   `〇`(U+3007) 같은 비십진 숫자까지 남기면 금칙어를 쪼개는 우회 수단이 되므로 `Nd`로 좁힌다.
4. 같은 방식으로 정규화한 금칙어가 결과 문자열에 부분 문자열로 포함되면 차단한다.

부분 문자열 매칭이므로 오탐(Scunthorpe 문제)이 목록 품질에 직결된다.
`보지`(보지 못했다), `자지`(자지 않았다), `rape`(grape), `tit`(title), `cock`(cocktail), `ass`(assassin)처럼
일상 표현에 흔히 포함되는 항목은 **목록에 넣지 않는다.** 명백한 욕설·혐오·성적 표현만 등재한다.

## 목록 로딩과 폴백

- backend는 `src/main/resources/public-content/banned-words.json`을 기동 시 로드·검증한다. 이 검증은 backend
  JSON 자체의 schema·중복·redundant entry를 확인하지만, iOS 사본과의 parity를 확인하지 않는다.
- iOS는 시작 시 `UserDefaults` 캐시를 사용하고, 캐시가 없거나 비어 있으면 앱 번들에 포함된
  `ios/Dutypark/Core/ContentFilter/banned-words.json` 사본을 사용한다. 번들 파일을 읽지 못할 때는
  `ContentFilterStore.emergencyWords` 정적 목록으로 내려간다.
- backend JSON, iOS bundled JSON, `emergencyWords`는 중복된 목록 소스다. 자동 동기화·생성·동일성 검증이나 CI
  parity check가 없으므로, 한 소스만 갱신되어 차단 결과가 달라질 수 있다는 residual risk를 숨기지 않는다.
- 웹은 시작 시 `localStorage` 캐시를 사용하고 fetch 결과를 갱신한다. 동일 정규화와 private D-Day 예외는
  반영 완료됐지만, 캐시가 없고 fetch가 실패하면 빈 목록으로 남아 client check가 fail-open되는 잔여 위험이
  있다. 웹 cold-start/fetch fail-open 해소가 남은 작업이며, 그 전까지 웹 필터의 운영 보호는 서버 enforcement
  범위를 함께 확인해야 한다.
- 서버 경계 검증이 적용된 D-Day 공개 제목과 근무유형/기본 근무유형 이름은 목록 캐시가 없는 직접 API 호출도
  HTTP 400 response의 `code=contentFilter.blocked`로 거부한다. private D-Day 제목은 서버 필터를 적용하지 않아
  허용한다. Schedule/Todo의 모든 서버 mutation에 server enforcement가 적용된 것은 아니다.

## 약관 개정

`V2.2.41`의 제8조 3항 "서비스는 이용자 콘텐츠를 사전에 검열하지 않으며"가 1.2 요구사항을 정면으로
부정하는 문장이므로 교체한다. 기존 마이그레이션은 불변이므로 새 TERMS 버전을 발행한다.

- 새 마이그레이션: `V2.2.47__publish_terms_with_content_filter.sql`
- 개정 문안:
  > 3. 서비스는 금지 콘텐츠 필터를 통해 명백한 위반 콘텐츠의 등록을 게시 시점에 차단하며, 필터로
  >    걸러지지 않은 콘텐츠는 신고 접수 후 제10조에 따라 조치합니다. 다만 서비스 제공자가 모든 이용자
  >    콘텐츠를 상시 모니터링할 의무를 지는 것은 아닙니다.

## 작업 분할

- **WP1 백엔드** — `src/main/**`, `src/test/**` (리소스, API, mutation 경계 검증, 약관 마이그레이션)
- **WP2 웹** — `frontend/**`
- **WP3 iOS** — `ios/**` (UserDefaults 캐시와 번들 fallback 포함)

WP1·WP3은 위 API 계약과 매칭 규칙을 기준으로 반영되었고, WP2(웹)는 정규화·private D-Day 예외를 반영
완료했으며 cold-start/fetch fail-open 해소가 남아 있다. 파일 겹침 없음.
