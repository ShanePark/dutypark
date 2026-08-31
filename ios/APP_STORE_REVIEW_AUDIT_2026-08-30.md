# Dutypark iOS App Store 제출 전 심사 감사 보고서

- 기준일: 2026-08-31 (KST)
- 대상: 실제 App Store 심사 계정, 운영 백엔드, iOS Release 앱
- 운영 API: https://dutypark.o-r.kr/api/
- Source baseline: b33316fe897f4c424fe23f3f82c6ae18a65171f6 (현재 HEAD)
- D-Day 수정 포함 커밋: 15293c6a
- 작업 상태: 이 보고서는 현재 working tree에서 갱신 중이며 아직 문서 변경이 커밋되지 않음
- 기기: iPhone 13 mini 및 iPhone 17 Pro, iOS 26.5 Simulator
- 빌드: 운영 API를 사용하는 Release build
- 최종 결론: 미해결 S1/S2 제품 결함 없음. 핵심 reviewer path는 READY (조건부)

이 문서는 실제 심사자가 앱을 처음 실행하는 상황을 기준으로 수행한 최신 검증의
canonical 요약이다. 테스트 계정의 비밀번호, 토큰, 쿠키, OAuth secret, private key,
device token은 이 문서와 저장소에 기록하지 않는다. 심사 계정 자격 증명은 App Store
Connect의 보안 입력란에서만 관리한다.

## 1. 최종 판정

현재 Release 앱의 로그인, 주요 탭, 운영 데이터 조회, 대표 CRUD, 게스트 공개 캘린더,
설정 경계, 다른 화면 크기 회귀를 확인했다. 앱 CrashReporter에서 Dutypark crash
report는 0건이었다.

| 영역 | 결과 | 근거 |
|---|---|---|
| 운영 Release build | PASS | /private/tmp/dutypark-final-release-build.log |
| iPhone 13 mini 설치·launch | PASS | 최종 Release와 로그인 Home 화면 확인 |
| iPhone 17 Pro 교차 기기 | PASS | Release install/launch 및 운영 UI 회귀 12/12 |
| iOS unit test | PASS | DutyparkTests 1,159/1,159, 0 FAIL |
| 인증·5개 primary tab | PASS | 로그인, Home, Calendar, Todo, Team, More |
| 로그아웃·잘못된 비밀번호·재로그인 | PASS | 운영 계정 실제 UI 흐름 |
| Guest public calendar | RESOLVED/PASS | 계정 공개 범위 수정, API 및 live UI 재검증 |
| 운영 9·10월 대표 데이터 | PASS | 일정, 근무표, Todo, D-Day 조회·재진입 확인 |
| 임시 일정·Todo·D-Day CRUD | PASS | 생성·상세·수정·삭제 확인 후 임시 데이터 정리 |
| D-Day 삭제 모달 잔류 결함 | RESOLVED | 제품 수정 및 focused/Release 회귀 통과 |
| CrashReporter | PASS | 이번 검증 범위의 Dutypark crash report 0건 |

핵심 reviewer path는 제출 가능한 상태다. 다만 실제 App Store Connect 저장값,
실기기 APNs/OAuth, 일회용 계정에서의 최종 삭제처럼 이 저장소와 심사 계정만으로
완결할 수 없는 항목은 조건부 위험으로 남긴다. 이는 현재 확인된 제품 결함과
구분한다.

## 2. 검증 원칙

상태는 PASS(직접 확인), RESOLVED(수정 후 재검증), CONDITIONAL(외부 게이트 잔여),
BLOCKED/SKIP/NOT RUN(환경·계정 보존·확장 범위로 미실행)으로 구분한다.
자동 fixture 결과는 운영 계정 PASS로 합산하지 않으며, 임시 레코드는 고유 제목과
소유자를 확인한 뒤 정리하고 기존 대표 데이터는 삭제·덮어쓰지 않는다.

## 3. 환경과 최종 증거

### 3.1 Source와 build

Source baseline은 Git HEAD b33316fe897f4c424fe23f3f82c6ae18a65171f6이며 D-Day
수정 커밋 15293c6a를 포함한다. 검증은 iOS 26.5의 iPhone 13 mini와 iPhone 17 Pro
Release에서 수행했다. 본 보고서는 working tree에서 갱신 중인 미커밋 문서이며,
문서 변경을 커밋된 source baseline으로 표현하지 않는다.

### 3.2 저장소에 보존한 최종 화면 증거

- ios/review-evidence/2026-08-31/final-release-home-clean.png
- ios/review-evidence/2026-08-31/final-release-iphone17pro-home.png

두 이미지는 최신 Release를 각 시뮬레이터에 설치한 뒤 로그인 상태의 Home을
확인한 화면이다. 심사 계정 비밀번호·토큰·불필요한 개인 연락처는 화면에 없다.

### 3.3 실행 로그

핵심 로그는 임시 경로에 보존했다: /private/tmp/dutypark-final-release-build.log,
/private/tmp/dutypark-final-unit-tests.log, /private/tmp/dutypark-review-login-smoke-retry.log,
/private/tmp/dutypark-review-calendar-data-final.log, /private/tmp/dutypark-review-todo-seed-final-5.log,
/private/tmp/dutypark-review-schedule-crud-retry.log, /private/tmp/dutypark-review-todo-crud.log,
/private/tmp/dutypark-review-dday-crud-final-fixed.log, /private/tmp/dutypark-review-auth-guest-final-5.log,
/private/tmp/dutypark-review-safe-navigation-final.log, /private/tmp/dutypark-guest-public-live.log,
/tmp/dutypark-guest-visibility-focused.log.
임시 로그는 제출물로 간주하지 않으며, 최종 화면 증거는 저장소의 2026-08-31 파일을 사용한다.

## 4. 핵심 reviewer 흐름

운영 Release에서 이메일 로그인·Home·Calendar·Todo·Team·More 이동, 로그아웃,
잘못된 비밀번호, guest 안내·정책·지원·재로그인, safe navigation, 설정 테마와
AI/사진/파일 picker 취소, 미저장 Todo 폐기를 모두 확인했다. 결과는 PASS이며
5개 primary tab과 crash report 0건은 위 요약 및 교차 기기 표에 집계했다.
계정·팀·친구 삭제와 신고 최종 제출은 심사 계정 보존을 위해 실행하지 않고
진입·설명·취소 경계만 확인했다. 최종 mutation은 별도 일회용 계정에서 진행한다.

## 5. Guest public calendar 401 해소

초기 guest 조회의 401은 앱 코드의 공개 우회 누락이 아니라 심사 계정의
calendarVisibility가 FRIENDS였기 때문에 발생했다. 서버와 iOS의 정책은 게스트에게
PUBLIC 계정만 허용하고 공개 일정·공개 D-Day만 반환하도록 되어 있어 privacy
정책을 우회하는 코드 변경을 하지 않았다.

심사 계정에 기존 인증 API를 사용해 공개 범위를 PUBLIC으로 설정했다.

| 확인 항목 | 결과 |
|---|---|
| 인증 member 조회 후 공개 범위 | PUBLIC |
| 비인증 member preview | HTTP 200 |
| 비인증 2026-09 calendar/duty/schedules | HTTP 200, 근무 42건 |
| 비인증 2026-10 calendar/duty/schedules | HTTP 200, 근무 42건 |
| 비인증 공개 일정 | 공개 범위 필터 적용 |
| 비인증 D-Day | 공개 D-Day 2건, private 항목 미노출 |
| 공개 member preview 민감 필드 | email/social ID/password 미노출 |
| backend visibility focused | 4/4 PASS |
| iPhone 13 mini guest live UI | 74.124s PASS |

실제 UI 흐름은 로그아웃 → guest universal link → 회원명·D-Day 표시 →
2026-09/10 월 선택 → 심사 계정 재로그인 순서로 확인했다. 심사 기간 중에는
이 계정의 공개 범위를 PUBLIC으로 유지해야 한다.

## 6. 운영 심사 데이터

대표 데이터는 심사자가 기능을 즉시 확인할 수 있도록 실제 생활과 유사한 제목,
날짜, 상태를 사용했다. 기존에 이미 존재하는 데이터는 중복 생성하지 않고
보존했다.

### 6.1 개인 일정

| 월 | 입력·확인한 대표 일정 |
|---|---|
| 2026-09 | 9월 첫 주 운영 계획; 월간 보고서 제출; 가을 운영 워크숍; 9월 중간 회고; 월말 체크인 |
| 2026-10 | 10월 목표 정리; 가족과 보내는 휴일; 팀 프로젝트 발표 준비; 친구와 브런치; 다음 달 준비 |

9월 5건은 중복 확인 후 필요한 항목만 유지했고, 10월 5건은 생성 후 날짜 상세와
월 이동을 확인했다. 두 달 모두 다른 월로 이동했다가 돌아오는 server-backed
reload로 재조회했다.

### 6.2 근무표

| 월 | 결과 |
|---|---|
| 2026-09 | 기존 근무표가 populated 상태임을 확인. 덮어쓰기하지 않음 |
| 2026-10 | 기존 근무표가 populated 상태임을 확인. 덮어쓰기하지 않음 |

각 월의 확인 로그에는 REVIEW_DUTY_SKIP_POPULATED가 기록되어 있다. 운영 근무표를
예시 데이터로 교체하지 않았으며, 실제 팀·근무 관계를 보존했다.

### 6.3 Todo

| 상태 | 마감일 | 제목 |
|---|---|---|
| TODO | 2026-09-05 | 9월 근무표 최종 확인 |
| IN_PROGRESS | 2026-09-18 | 9월 팀 회의 자료 준비 |
| DONE | 2026-09-30 | 9월 급여 명세 확인 |
| TODO | 2026-10-03 | 10월 근무표 공유 |
| IN_PROGRESS | 2026-10-15 | 10월 휴가 일정 정리 |
| DONE | 2026-10-28 | 10월 건강검진 예약 |

6건 모두 상태·마감일을 확인하고 Todo 탭을 이탈한 뒤 재진입하여 다시 조회했다.
별도의 임시 Todo lifecycle은 생성·상세·제목 수정·상태 이동·삭제 취소·삭제
확인까지 수행하고 정리했다.

### 6.4 D-Day

기존 대표 D-Day인 가을 휴가 시작과 팀 프로젝트 발표는 보존했다. 별도 고유 임시
D-Day로 생성·상세·제목 수정·삭제 confirmation·삭제 후 Calendar reload를
검증했다. 임시 D-Day는 남기지 않았다.

## 7. 결함과 수정

### REVIEW-001 — 자동화 harness 접근성 문제

Calendar와 Todo seed의 초기 실패는 중첩 ScrollView와 시스템 DatePicker label을
XCTest가 안정적으로 찾지 못한 문제였다. modal 바깥 scroll 위치와 locale label
fallback을 테스트 helper에만 보정했으며 운영 앱/API 계약은 변경하지 않았다.
Calendar seed와 Todo seed/reentry는 최종 1/1 PASS다.

### REVIEW-002 — D-Day 삭제 후 stale modal

삭제 API 성공 뒤 confirmation route와 modal dismiss 상태가 경쟁하여 카드 삭제 후
모달이 남을 수 있는 제품 결함을 확인했다. CalendarView에 삭제 성공 callback과
성공 상태 기반 dismissability를 반영하고, CalendarFeatureTests에 순서·잠금 경계
회귀를 추가했다.

- focused unit 2건: PASS
- 수정 Release 운영 D-Day CRUD/reload: 51.228s PASS
- 최종 iPhone 13 mini/17 Pro Release 회귀: PASS
- 상태: RESOLVED

### REVIEW-003 — Guest public calendar

401 원인을 계정 visibility 설정으로 분리했다. 심사 계정만 기존 인증 API로
PUBLIC으로 설정했고, FRIENDS/FAMILY/PRIVATE 사용자를 공개하는 코드 변경은 하지
않았다. backend focused 4/4, 비인증 API 200, iOS guest live 74.124s로 재검증했다.

## 8. 자동 검증과 교차 기기

| 검증 | 결과 |
|---|---|
| DutyparkTests 전체 | 1,159/1,159 PASS |
| iPhone 13 mini Release build/install/launch | PASS |
| iPhone 13 mini 운영 로그인·핵심 reviewer path | PASS |
| iPhone 17 Pro Release build/install/launch | PASS |
| iPhone 17 Pro 운영 UI 회귀 | 12/12 PASS |
| iPhone 17 Pro unit 회귀 | 1,159/1,159 PASS |
| 2026-09/10 일정 seed/reentry | PASS |
| 2026-09/10 근무표 populated 보존 | PASS |
| Todo 6건 seed/reentry | PASS |
| 일정·Todo·D-Day 임시 CRUD | PASS |
| 설정·picker·미저장 draft 취소 | PASS |
| CrashReporter | Dutypark report 0건 |

초기 테스트 실행에서 확인된 selector, gesture, simulator 종료 문제는 제품
crash나 데이터 결함으로 확정되지 않았으며, 보정된 focused 실행에서 재현 없이
통과했다. 오래된 harness 시도와 세부 140개 수준의 미실행 목록은 현재 판단에
필요한 요약으로 대체한다.

## 9. 남은 위험과 제출 전 조치

| 항목 | 상태 | 남은 조치 |
|---|---|---|
| 앱 핵심 reviewer path | READY (조건부) | 심사 기간 동안 운영 API와 계정 유지 |
| 계정 최종 삭제 | SKIP | 심사 계정이 아닌 일회용 계정으로 실제 완료·receipt 확인 |
| 팀/친구/신고 destructive mutation | SKIP | 별도 안전 계정에서만 최종 제출 검증 |
| App Store Connect 메타데이터 | 외부 확인 필요 | Privacy Details, Age Rating, Review Notes, 계정 입력값과 build processing 확인 |
| OAuth 완료 | 외부 의존 | 실기기와 실제 provider 계정에서 취소·복귀·완료 확인 |
| APNs 실수신 | Simulator 한계 | entitlement와 운영 실기기 token/수신을 별도 확인 |
| 오프라인·network recovery | 확장 검증 | 실네트워크 단절·복귀·outbox 중복 방지를 별도 실행 |
| session expiry/401 | 확장 검증 | 안전한 fixture 또는 서버 지원으로 만료·재인증 확인 |
| 상세 VoiceOver/Dynamic Type/실기기 layout | 확장 검증 | 제출 전 실기기 점검 권장 |

위 항목들은 현재 확인된 미해결 S1/S2 제품 결함이 아니다. 계정 보존, 실기기,
외부 provider, App Store Connect 권한 또는 네트워크 상태가 필요한 별도 게이트다.
실제 심사 계정을 삭제하거나 친구·팀 관계를 변경하는 방식으로 확인하지 않는다.

## 10. 제출 체크리스트

- [x] 운영 API를 사용하는 Release build 성공
- [x] iPhone 13 mini에 최신 Release 설치·launch
- [x] iPhone 17 Pro 교차 기기 Release 회귀
- [x] 심사 계정 로그인·logout·wrong password·relogin
- [x] Home·Calendar·Todo·Team·More 핵심 진입
- [x] 2026-09/10 대표 일정과 기존 근무표 보존
- [x] Todo 6건 상태·마감일·재진입
- [x] 임시 일정·Todo·D-Day CRUD 및 cleanup
- [x] Guest public calendar 401 해소 및 live UI
- [x] D-Day stale modal 제품 수정·회귀
- [x] Unit 1,159/1,159 및 운영 UI 12/12
- [x] CrashReporter scan에서 Dutypark report 0건
- [x] 최종 Release Home 증거 두 기기분 보존
- [ ] 일회용 계정으로 최종 계정 삭제 완료·receipt 확인
- [ ] App Store Connect 실제 Privacy Details/Review Notes/계정/build processing 확인
- [ ] OAuth 완료·APNs 수신 실기기 확인
- [ ] 오프라인·session expiry 확장 검증

## 11. 제출 시 운영 주의사항

1. App Store Connect의 Review Notes에 핵심 탭 경로와 심사 계정 사용 방법을
   영어로 기재한다.
2. 심사 계정의 사용자명과 비밀번호는 App Review Information의 secure fields에만
   입력한다.
3. 심사 기간 동안 운영 API, 심사 계정, 공개 캘린더 설정을 유지한다.
4. 심사자가 삭제 기능을 확인할 수 있도록 삭제 위치와 비동기 처리 정책을
   Review Notes에 설명하되, 심사 계정 자체를 사전 삭제하지 않는다.
5. 카메라·Photos·Files·AI 일정 파싱은 사용자가 해당 기능을 선택할 때만 권한과
   동의 화면을 표시한다.
6. 제출 전 App Store Connect에서 실제 build processing과 export compliance를
   확인한다.

## 12. 결론

최신 HEAD 기준으로 core reviewer path에서 재현되는 S1/S2 제품 결함은 없다.
D-Day stale modal은 제품 코드 수정 후 focused unit과 운영 Release CRUD로
RESOLVED 되었고, guest public calendar 401은 심사 계정의 공개 범위를 PUBLIC으로
정정한 뒤 backend 4/4와 iOS live UI로 PASS 되었다.

따라서 현재 판정은 다음과 같다.

- 핵심 reviewer path: READY (조건부)
- 실제 운영 데이터: 2026-09/10 일정·근무표·Todo·D-Day 준비 완료
- 최신 Release: iPhone 13 mini 및 iPhone 17 Pro에서 설치·실행 확인
- 자동 검증: Unit 1,159/1,159, 운영 UI 12/12
- 앱 crash: 이번 Simulator 범위에서 0건
- 남은 작업: App Store Connect 실제 제출 입력, 일회용 계정 삭제, 실기기·외부
  서비스·오프라인·session expiry의 확장 확인

이 보고서는 Apple의 실제 심사 승인 자체를 보장하지 않는다. 다만 저장소에서
확인 가능한 핵심 기능과 운영 심사 계정 흐름은 제출 가능한 상태이며, 남은 항목은
외부 환경 또는 파괴적 동작을 안전하게 분리한 조건부 게이트다.
