# 금지 콘텐츠 필터 (Content filter)

App Store Guideline 1.2가 요구하는 "a method for filtering objectionable material from being posted"을
충족하기 위한 최소 구현. 기존 신고·차단·문의는 이미 충족되어 있으므로 이 문서는 필터만 다룬다.

## 결정 사항

| 항목 | 결정 |
| --- | --- |
| 적용 범위 | 신고 대상 3종(SCHEDULE / TODO / MEMBER)에 대응하는 사용자 입력 텍스트 |
| 검증 위치 | 클라이언트(웹·iOS)에서만. 서버는 목록만 제공하고 400을 내리지 않는다 |
| 차단 방식 | 저장 시도 시 검사해 저장을 중단하고 안내 메시지 표시 |
| 알림 시점 | 저장/등록 버튼을 눌렀을 때. 입력 중 실시간 검사는 하지 않는다 |
| 목록 위치 | 백엔드 리소스 파일 1벌 + 조회 API. 클라이언트가 받아서 캐시 |
| 첨부파일 | 이번 범위 제외. 기존 신고 기반 대응 유지 |

클라이언트 검증만 두므로 API 직접 호출은 막지 못한다. 심사 요건(앱에서 게시 전 차단)은 충족하며,
서버 검증은 이후 방어층으로 덧붙일 수 있다.

## 적용 대상 필드

| 신고 대상 | 필드 | 웹 | iOS |
| --- | --- | --- | --- |
| SCHEDULE | 개인 일정 `content`, `description` | `DayDetailModal.vue` | `CalendarViewModel.swift` |
| SCHEDULE | 팀 일정 `content`, `description` | `TeamView.vue` | `TeamViewModel.swift` |
| TODO | `title`, `content` | `TodoBoardView.vue`, `DutyView.vue` | `TodoViewModel.swift` |
| MEMBER | 회원가입 이름 | `SsoSignupView.vue` | `SsoSignupView.swift` |
| MEMBER | 보조계정 이름 | `MemberView.vue` | `SettingsViewModel.swift` |

범위 밖: 첨부파일, D-Day 제목, 팀 이름/설명(관리자 전용 생성이라 일반 UGC가 아님).
회원 본인 이름 변경 기능은 존재하지 않으므로 MEMBER는 위 두 입력이 전부다.

## API 계약 (단일 소유자: 백엔드)

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
- 원본: `src/main/resources/public-content/banned-words.json` (`{ "schemaVersion": 1, "words": [...] }`).
  기동 시 로드·검증하며, 검증 실패는 기동 실패로 만든다.

## 매칭 규칙 (웹·iOS 동일 구현 필수)

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

- 클라이언트는 시작 시 한 번 조회하고 로컬에 영속 캐시한다(웹 `localStorage`, iOS `UserDefaults`).
- 캐시가 있으면 캐시로 즉시 검사하고, 응답을 받으면 갱신한다.
- 캐시도 응답도 없는 최초 오프라인 상태에서는 **저장을 막지 않는다.** 가용성을 우선한다.

## 약관 개정

`V2.2.41`의 제8조 3항 "서비스는 이용자 콘텐츠를 사전에 검열하지 않으며"가 1.2 요구사항을 정면으로
부정하는 문장이므로 교체한다. 기존 마이그레이션은 불변이므로 새 TERMS 버전을 발행한다.

- 새 마이그레이션: `V2.2.47__publish_terms_with_content_filter.sql`
- 개정 문안:
  > 3. 서비스는 금지 콘텐츠 필터를 통해 명백한 위반 콘텐츠의 등록을 게시 시점에 차단하며, 필터로
  >    걸러지지 않은 콘텐츠는 신고 접수 후 제10조에 따라 조치합니다. 다만 서비스 제공자가 모든 이용자
  >    콘텐츠를 상시 모니터링할 의무를 지는 것은 아닙니다.

## 작업 분할

- **WP1 백엔드** — `src/main/**`, `src/test/**` (리소스, API, 약관 마이그레이션)
- **WP2 웹** — `frontend/**`
- **WP3 iOS** — `ios/**`

WP2·WP3은 위 API 계약과 매칭 규칙을 고정 전제로 진행한다. 파일 겹침 없음.
