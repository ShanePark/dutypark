# Dutypark iOS App Store 실제 심사 계정 전수 검증 보고서

- 기준일: 2026-08-30 (KST)
- 최종 갱신: 2026-08-31 (KST)
- 판정: **조건부 진행 중 — core reviewer path는 준비됐으나 확장 전수 검증·최종 데이터 정합성은 미완료**
- 대상: App Store 심사용 운영 계정 및 운영 백엔드
- 코드 기준: `6982ebd0` + 검증 중 working tree의 D-Day dismissal 수정 (`ios/Dutypark/Features/Calendar/CalendarView.swift`, `ios/DutyparkTests/CalendarFeatureTests.swift`)
- 기기: `iPhone 13 mini`, `iPhone 17 Pro`, iOS 26.5 Simulator
- 빌드: Release, 운영 API 연결 **PASS**
- 현재 상태: 심사용 계정 인증·guest 경계·5개 탭 **PASS**, safe navigation 4개 케이스 **PASS**, 일정·D-Day·Todo 임시 CRUD **PASS**, 2026-09/10 대표 데이터·근무표 보존·두 기기의 fixed Release install/launch·clean Home·CrashReporter scan **PASS**, 확장 전수 검증 진행 중
- 비밀값: 비밀번호, access/refresh token, cookie, private key, OAuth secret은 이 문서와 증거에 기록하지 않는다. 심사용 계정 자격 증명은 App Store Connect의 보안 입력란에서만 관리한다.

이 문서는 2026-08-30에 시작한 운영 심사 계정의 실제 앱 검증을 위한 단일 진행 기록이다. 이전 로컬 fixture 및 자동 검증 기록은 참고 자료로만 연결하며, 현재 운영 계정의 기능 PASS로 합산하지 않는다.

## 1. 목표와 완료 기준

실제 App Review reviewer가 처음 실행한 상황을 가정하고, 최신 Release 앱에서 로그인·주요 탭·상세 화면·생성/수정·공유·오류·설정·지원 흐름을 운영 백엔드로 확인한다. 2026년 9월과 10월에 근무·개인 일정·팀 일정·Todo를 실제 생활과 유사한 형태로 채우고, 심사 계정으로 재실행해도 데이터가 유지되는지 확인한다.

완료 조건:

- [x] 최신 Release 빌드가 운영 API를 사용해 빌드됨
- [x] `iPhone 13 mini` Simulator에 설치·실행됨
- [x] D-Day 수정이 포함된 최종 Release를 exact `iPhone 13 mini` simulator에 설치·launch하고 clean Home evidence를 보존함
- [x] 심사용 계정 로그인 전용 UI test가 성공함
- [x] 로그인 상태에서 Home 화면이 표시됨
- [x] 2026-09 일정 5건의 입력/중복 방지 처리와 서버 재조회가 성공함
- [x] 2026-10 일정 5건의 입력과 서버 재조회가 성공함
- [x] 2026-09·10 근무표가 이미 populated 상태임을 확인하고 덮어쓰지 않음
- [x] Todo 6건을 상태·마감일별로 입력하고 탭 이탈 후 재진입해 재조회함
- [x] Safe navigation 4개 케이스를 실제 운영 계정에서 통과시킴. 초기 aggregate의 자동화 실패 케이스는 최종 단독 재실행으로 보완함
- [x] 임시 Todo·일정·D-Day의 create/read/update/delete와 destructive confirmation 경계를 검증하고 임시 데이터를 정리함
- [x] D-Day 삭제 성공 후 stale dismiss/잠금 경쟁 제품 결함을 수정하고 focused 2건 및 Release 운영 CRUD를 재검증함
- [x] 일정 CRUD, 설정·picker 취소, 인증·guest 경계 시나리오를 추가 실행함
- [ ] 인증·게스트·Home·Calendar·Todo·Team·More의 접근 가능한 기능 전수 확인
- [ ] 2026-09 및 2026-10 대표 데이터 생성·조회·수정 결과를 서버와 앱 재실행으로 확인
- [ ] 앱 crash, hang, 무한 로딩, 중복 저장, 데이터 유실이 없음
- [x] 이번 simulator CrashReporter 경로에서 Dutypark crash report 0건을 확인함 (hang·전체 runner log 판정은 별도)
- [x] 발견 결함을 재현 가능한 증거와 함께 기록하고, D-Day 수정 시 RED→GREEN focused 검증 수행
- [ ] 기존 운영 데이터가 의도하지 않게 변경되지 않았음을 확인
- [x] 심사 계정에 남길 최종 대표 데이터와 실행 중 임시 데이터를 구분하고 임시 CRUD 레코드를 정리함
- [x] 미검증·BLOCKED·destructive SKIP 항목과 제출 리스크를 최종 판정에 명시

상태 정의:

| 상태 | 의미 |
|---|---|
| `PASS` | 현재 실행에서 실제 기대 결과까지 확인됨 |
| `FAIL` | 재현 가능한 제품 결함 또는 데이터 오류가 확인됨 |
| `BLOCKED` | 권한·외부 서비스·환경 등으로 실행할 수 없음 |
| `SKIP` | 데이터 보존 또는 파괴적 동작 방지 원칙에 따라 실행하지 않음 |
| `NOT RUN` | 아직 실행하지 않음. 이전 날짜의 결과로 대체하지 않음 |
| `RESOLVED` | 결함 또는 자동화 문제를 원인 분리·수정한 뒤 focused 및 관련 재검증까지 통과함 |

## 2. 검증 범위와 기존 문서와의 구분

### 2.1 이번 실행의 범위

- 운영 API: `https://dutypark.o-r.kr/api/`
- 실제 심사 계정으로 수행하는 앱 UI 및 서버 persistence 검증
- `iPhone 13 mini` iOS 26.5 Simulator의 한국어 기준 흐름
- 운영 계정에 남겨도 되는 9·10월 대표 데이터 생성
- 앱 로그, crash report, 서버 재조회, 앱 재실행 결과의 상호 대조

### 2.2 이전 기록의 취급

| 문서 | 성격 | 이번 판정에서의 취급 |
|---|---|---|
| [`APP_STORE_PRE_SUBMISSION_QA.md`](./APP_STORE_PRE_SUBMISSION_QA.md) | 2026-08-28 로컬 fixture·자동/실계정 과거 QA 계획 및 결과 | 배경·기존 결함 이력으로만 참조. 이번 운영 계정 PASS로 합산하지 않음 |
| [`APP_STORE_REVIEW_AUDIT_2026-08-28.md`](./APP_STORE_REVIEW_AUDIT_2026-08-28.md) | 날짜별 제출 전 감사 보고서 | 과거 source/build의 증거로만 참조 |
| [`APP_STORE_REVIEW_AUDIT_2026-08-29.md`](./APP_STORE_REVIEW_AUDIT_2026-08-29.md) | 로컬 자동화·스크린샷·제출 게이트 보고서 | 현재 운영 계정의 실제 동작 증거로 재사용하지 않음 |
| `ios/review-evidence/2026-08-29/README.md` | 이전 실행 artifact provenance | 현재 실행 artifact가 아니므로 별도 집계 |

기존 문서는 수정하지 않는다. 자동 fixture가 PASS하더라도 운영 계정에서 같은 기능을 실제로 확인하기 전까지는 이 보고서의 해당 항목을 `NOT RUN`으로 둔다.

## 3. 안전·데이터·증거 원칙

- [x] 운영 API endpoint와 Release 구성을 확인함
- [x] 심사용 계정 비밀번호와 세션 비밀값을 문서·로그·스크린샷에 기록하지 않음
- [ ] 실행 전 운영 계정의 일정·근무·Todo·D-Day·알림·친구·팀 snapshot을 저장함
- [ ] 기존 row의 서버 ID와 digest를 보존함
- [ ] 새 데이터는 날짜·제목·내용·공개 범위·서버 ID를 실행 로그에 등록함
- [ ] 앱에서 저장한 뒤 앱 재실행과 서버 재조회로 persistence를 확인함
- [ ] 기존 데이터와 새 데이터의 변경 범위를 구분함
- [ ] 오류가 나면 재시도 전 중복 생성 여부를 먼저 확인함
- [x] clean Home 스크린샷에 credential, token, 개인 연락처, 불필요한 실제 개인정보가 보이지 않음을 확인함
- [ ] 계정 삭제·팀원 제거·친구 차단/삭제·최종 신고 제출은 아래 destructive SKIP 원칙을 적용함

### 3.1 Destructive SKIP 원칙

이번 계정은 App Store 제출 시 reviewer에게 제공할 계정이므로 다음 동작은 실제 상태를 최종 변경하지 않는다.

- 계정 삭제의 최종 확인/실제 완료 요청: `SKIP` — 심사 계정 보존 필요
- 팀 삭제 또는 팀원 제거의 최종 확인: `SKIP` — 운영 관계 복구 비용이 큼
- 친구 차단·친구 삭제의 최종 제출: `SKIP` — reviewer에게 보여줄 친구·공유 데이터 보존 필요
- 신고의 최종 제출: `SKIP` — 운영 신고 기록을 임의로 남기지 않음. 신고 sheet·validation·차단 선택 UI까지만 확인
- 읽은 알림 전체 삭제: `SKIP` 또는 별도 안전 알림으로 제한 — 심사 화면용 알림 데이터 보존

위 기능의 진입, 설명, 취소, 확인 모달, 오류 처리는 검증할 수 있다. 실제 destructive 완료 검증은 별도의 disposable 계정을 확보한 뒤 별도 실행으로 진행한다.

## 4. 2026년 9·10월 심사 계정 데이터 계획

아래 표는 운영 계정에 남길 대표 데이터의 계획과 현재 실행 결과다. 이번 실행에서 확인된 항목만 `PASS`로 표시한다. 서버 ID는 비밀값이 아니지만 현재 로그에 노출되지 않았으므로, 별도 API snapshot을 확보하기 전까지는 기록하지 않는다.

### 4.1 기존 D-Day 중복 방지

| 기존 항목 | 날짜 | 처리 원칙 | 상태 |
|---|---|---|---|
| 가을 휴가 시작 | 2026-09-18 | 동일 제목·날짜의 D-Day를 새로 생성하지 않음. 공개 범위·고정 여부·상세 표시만 확인 | `NOT RUN` |
| 팀 프로젝트 발표 | 2026-10-09 | 동일 제목·날짜의 D-Day를 새로 생성하지 않음. 팀 일정·캘린더 표시와 함께 확인 | `NOT RUN` |

생성 전 D-Day 목록을 조회해 제목과 날짜가 같은 row의 서버 ID를 먼저 기록한다. 동명이지만 날짜·소유자·공개 범위가 다른 항목은 별도 항목으로 취급하지 않고 원본을 확인한 뒤 필요할 때만 추가한다.

### 4.1.1 임시 D-Day CRUD 실행 결과

실제 대표 D-Day를 변경하지 않도록 `심사 임시 D-Day <고유값>` 레코드만 대상으로 create→detail→title update→delete confirmation→confirm→Calendar reload를 수행했다. 초기 실행에서는 삭제 성공 뒤 stale presentation dismiss와 잠금 상태가 경쟁하는 제품 결함이 확인되었고, `CalendarView.swift`의 성공 dismiss 경로와 modal dismissability 정책을 수정했다. focused unit 2건이 `PASS`했고, 수정 Release·운영 API UI test도 `PASS (51.228s)`로 완료됐다. 테스트의 `defer` cleanup까지 통과해 임시 D-Day는 남기지 않았으며, 기존 `가을 휴가 시작`·`팀 프로젝트 발표`는 이 CRUD 대상에 포함하지 않았다.

| 항목 | 상태 | 증거 |
|---|---|---|
| D-Day create/edit/delete/reload (수정 후) | `PASS (51.228s)` | `/private/tmp/dutypark-review-dday-crud-final-fixed.log`, `/tmp/dutypark-review-dday-crud-final-fixed.xcresult` |
| stale dismiss/잠금 경쟁 focused unit 2건 | `PASS` | `/private/tmp/dutypark-dday-fix-focused-2.log` |
| 대표 D-Day 최종 삭제 | `SKIP` | 3.1 destructive SKIP 원칙 |

### 4.2 개인 일정 계획·실행 결과

| 계획 ID | 날짜·시간(KST) | 실제형 제목 | 공개 범위 의도 | 기대 화면 | 상태 |
|---|---|---|---|---|---|
| CAL-SEP-01 | 2026-09-01 | 9월 첫 주 운영 계획 | 친구 공개 | 9월 날짜 셀·상세 | `PASS` |
| CAL-SEP-02 | 2026-09-07 | 월간 보고서 제출 | 가족 공개 | 9월 날짜 셀·상세 | `PASS` |
| CAL-SEP-03 | 2026-09-14–2026-09-16 | 가을 운영 워크숍 | 친구 공개 | 9월 기간 일정 | `PASS` |
| CAL-SEP-04 | 2026-09-21 | 9월 중간 회고 | 나만 보기 | 9월 비공개 일정 상세 | `PASS` |
| CAL-SEP-05 | 2026-09-29 | 월말 체크인 | 전체 공개 | 9월 날짜 셀·상세 | `PASS` |
| CAL-OCT-01 | 2026-10-01 | 10월 목표 정리 | 친구 공개 | 10월 날짜 셀·상세 | `PASS` |
| CAL-OCT-02 | 2026-10-03 | 가족과 보내는 휴일 | 가족 공개 | 10월 종일 일정 | `PASS` |
| CAL-OCT-03 | 2026-10-08–2026-10-09 | 팀 프로젝트 발표 준비 | 친구 공개 | 10월 기간 일정 | `PASS` |
| CAL-OCT-04 | 2026-10-17 | 친구와 브런치 | 나만 보기 | 10월 비공개 일정 상세 | `PASS` |
| CAL-OCT-05 | 2026-10-30 | 다음 달 준비 | 전체 공개 | 10월 날짜 셀·상세 | `PASS` |

실행 결과: `ReviewCalendarDataUITests.testSeedsReviewAccountSeptemberAndOctoberCalendarData`가 2026-08-31에 154.603초 동안 성공했다. 9월 5건은 이미 존재하는 항목을 `REVIEW_SCHEDULE_SKIP_DUPLICATE`로 확인한 뒤 중복 생성하지 않았고, 10월 5건은 실제 입력 후 각 날짜 상세에서 확인했다. 각 월은 다른 월로 이동했다가 돌아오는 서버-backed reload로 재조회했다. 원문 로그는 `/private/tmp/dutypark-review-calendar-data-final.log`, 임시 테스트 원본은 `/private/tmp/dutypark-ios-review-current.oP4X3K/DutyparkUITests/ReviewCalendarDataUITests.swift`다.

별도의 현재 날짜 임시 레코드로 일정 lifecycle도 확인했다. `ReviewLiveCRUDUITests.testLiveReviewScheduleCreateUpdateDelete`는 운영 API에서 고유한 제목과 내용을 입력하고, 상세·수정·삭제 confirmation·삭제 후 목록 부재를 확인한 뒤 `PASS (47.735s)`로 끝났다. 임시 일정은 테스트 cleanup으로 제거했으며, 9·10월 대표 일정 10건의 수정·삭제를 의미하지 않는다. 증거는 `/private/tmp/dutypark-review-schedule-crud-retry.log` 및 `/tmp/dutypark-review-schedule-crud-retry.xcresult`다.

친구 태그·친구 캘린더·알림까지 확인한 결과는 아니다. 해당 항목은 전수 체크리스트에서 계속 `NOT RUN`으로 유지한다.

### 4.3 팀 일정 계획

| 계획 ID | 날짜·시간(KST) | 팀 일정 제목 | 기대 검증 | 상태 |
|---|---|---|---|---|
| TEAM-CAL-SEP-01 | 2026-09-03 10:00–11:00 | 9월 스프린트 계획 회의 | 팀 캘린더·팀원 표시 | `NOT RUN` |
| TEAM-CAL-SEP-02 | 2026-09-17 16:00–17:00 | 중간 진행 상황 공유 | 팀 일정 상세·수정 화면 | `NOT RUN` |
| TEAM-CAL-SEP-03 | 2026-09-25 13:00–14:00 | 릴리스 체크리스트 점검 | 팀 캘린더·월 이동 | `NOT RUN` |
| TEAM-CAL-OCT-01 | 2026-10-02 10:00–11:00 | 10월 프로젝트 킥오프 | 팀 캘린더·팀원별 근무 | `NOT RUN` |
| TEAM-CAL-OCT-02 | 2026-10-09 09:00–10:00 | 프로젝트 발표 리허설 | 기존 발표 D-Day와 교차 확인 | `NOT RUN` |
| TEAM-CAL-OCT-03 | 2026-10-23 17:00–18:00 | 발표 후 회고 | 팀 일정 상세·검색 | `NOT RUN` |

### 4.4 근무 계획

실제 팀에 이미 등록된 근무 유형을 우선 사용한다. 아래 명칭은 원래 입력하려던 표시 예시이며, 이번 실행에서는 월간 근무표를 덮어쓰지 않았다. 두 달 모두 이미 populated 상태였으므로 운영 데이터 보호를 위해 신규 batch 입력을 생략하고 보존을 확인했다.

| 계획 ID | 날짜·시간(KST) | 근무 유형 예시 | 기대 검증 | 상태 |
|---|---|---|---|---|
| DUTY-SEP-01 | 2026-09-01 09:00–18:00 | 주간 근무 | 9월 첫 주 셀·Home 요약 | `NOT RUN` |
| DUTY-SEP-02 | 2026-09-03 18:00–2026-09-04 09:00 | 야간 근무 | 자정 경계·월간 셀 | `NOT RUN` |
| DUTY-SEP-03 | 2026-09-08 09:00–18:00 | 주간 근무 | 반복되는 근무 색상 | `NOT RUN` |
| DUTY-SEP-04 | 2026-09-12 13:00–21:00 | 대체 근무 | 시간대가 다른 근무 | `NOT RUN` |
| DUTY-SEP-05 | 2026-09-19 09:00–18:00 | 주간 근무 | 휴가 이후 근무 표시 | `NOT RUN` |
| DUTY-SEP-06 | 2026-09-24 18:00–2026-09-25 09:00 | 야간 근무 | 연속 날짜·팀 비교 | `NOT RUN` |
| DUTY-OCT-01 | 2026-10-01 09:00–18:00 | 주간 근무 | 10월 첫 주 셀 | `NOT RUN` |
| DUTY-OCT-02 | 2026-10-05 18:00–2026-10-06 09:00 | 야간 근무 | 자정 경계·Home 요약 | `NOT RUN` |
| DUTY-OCT-03 | 2026-10-13 09:00–18:00 | 교육/지원 근무 | 다른 근무 유형·색상 | `NOT RUN` |
| DUTY-OCT-04 | 2026-10-20 13:00–21:00 | 대체 근무 | 시간대가 다른 근무 | `NOT RUN` |
| DUTY-OCT-05 | 2026-10-27 09:00–18:00 | 주간 근무 | 월말 표시·팀 비교 | `NOT RUN` |

월간 근무표 보존 확인:

| 월 | 실행 결과 | 처리 | 상태 | 증거 |
|---|---|---|---|---|
| 2026-09 | 이미 populated | 전체 월 교체/덮어쓰기 생략 | `PASS` | `/private/tmp/dutypark-review-calendar-data-final.log`의 `REVIEW_DUTY_SKIP_POPULATED month=2026-09` |
| 2026-10 | 이미 populated | 전체 월 교체/덮어쓰기 생략 | `PASS` | `/private/tmp/dutypark-review-calendar-data-final.log`의 `REVIEW_DUTY_SKIP_POPULATED month=2026-10` |

개별 `DUTY-*` 행은 해당 날짜에 새 근무를 입력했다는 뜻이 아니므로 `NOT RUN`으로 유지한다. 이번 PASS는 두 달의 기존 근무표를 보호하면서 populated 상태를 확인했다는 범위에만 적용된다.

관리자 권한이 필요한 월간 일괄 입력은 실제 UI에서 가능한 경우에만 수행한다. 팀·근무 유형을 변경하는 파괴적 관리자 mutation은 3장의 `SKIP` 원칙을 따른다.

### 4.5 Todo 계획·실행 결과

| 계획 ID | 상태 컬럼 | 마감일 | 실제형 제목 | 기대 검증 | 상태 |
|---|---|---|---|---|---|
| TODO-SEP-01 | `TODO` | 2026-09-05 | 9월 근무표 최종 확인 | TODO 컬럼·마감일 | `PASS` |
| TODO-SEP-02 | `IN_PROGRESS` | 2026-09-18 | 9월 팀 회의 자료 준비 | 진행 중 컬럼·마감일 | `PASS` |
| TODO-SEP-03 | `DONE` | 2026-09-30 | 9월 급여 명세 확인 | 완료 컬럼·마감일 | `PASS` |
| TODO-OCT-01 | `TODO` | 2026-10-03 | 10월 근무표 공유 | TODO 컬럼·마감일 | `PASS` |
| TODO-OCT-02 | `IN_PROGRESS` | 2026-10-15 | 10월 휴가 일정 정리 | 진행 중 컬럼·마감일 | `PASS` |
| TODO-OCT-03 | `DONE` | 2026-10-28 | 10월 건강검진 예약 | 완료 컬럼·마감일 | `PASS` |

실행 결과: `ReviewTodoDataUITests.testReviewAccountTodoSeedAndReentry`가 2026-08-31에 345.489초 동안 성공했다. 위 6건은 UI로 생성하고 상태·마감일을 확인한 뒤 Home으로 이탈했다가 Todo 탭에 재진입하여 다시 확인했다. 원문 로그는 `/private/tmp/dutypark-review-todo-seed-final-5.log`, 상태·마감일 원본 목록은 `/private/tmp/dutypark-ios-review-current.oP4X3K/DutyparkUITests/ReviewTodoDataUITests.swift`의 `reviewTodoSpecs`다.

이번 실행은 `TODO`, `IN_PROGRESS`, `DONE` 세 컬럼을 대상으로 했다. 상세 수정·드래그 이동·첨부·오프라인 outbox·최종 삭제는 이 결과에 포함하지 않으며 전수 체크리스트에서 계속 별도 상태로 관리한다.

추가로 임시 Todo lifecycle을 확인했다. `ReviewTodoDataUITests.testReviewAccountTodoCreateEditMoveAndDeleteLifecycle`가 임시 Todo 생성·상세 조회·제목 수정·`TODO`→`IN_PROGRESS` 이동·삭제 취소·삭제 확인을 모두 통과했고 `PASS (100.099s)`였다. 삭제 후 안정적인 심사 대표 Todo 6건을 다시 확인했으며, 임시 카드는 남기지 않았다. 증거는 `/private/tmp/dutypark-review-todo-crud.log` 및 `/tmp/dutypark-review-todo-crud.xcresult`다. 이 테스트의 상태 이동은 semantic UI action을 우선 사용하므로, 별도 drag-and-drop 검증으로 합산하지 않는다.

### 4.6 설정·picker·미저장 draft 결과

`ReviewLiveCRUDUITests.testLiveReviewSettingsAndAttachmentPickerCancel`는 운영 계정에서 Dark→System 테마 전환, AI 동의 sheet 취소, Todo 사진 picker·파일 picker 진입 후 취소, 미저장 Todo draft 폐기 confirmation을 `PASS (47.865s)`로 완료했다. Light 시각 검증, 실제 파일/사진 선택·업로드, AI 동의 완료는 실행하지 않았다. 증거는 `/private/tmp/dutypark-review-settings-picker-final-4.log` 및 `/tmp/dutypark-review-settings-picker-final-4.xcresult`다.

### 4.7 사회·알림·프로필 보조 데이터

- [ ] 기존 친구 목록과 고정/비고정 순서를 snapshot함
- [ ] 실제 친구 캘린더에 표시 가능한 공유 일정이 최소 1개 있음
- [ ] friend request 또는 schedule tag 알림이 기존 목록에 있는지 확인함
- [ ] 읽지 않은 알림과 읽은 알림이 각각 최소 1개 있음
- [ ] 프로필 사진과 이름을 심사 화면에서 보여도 되는 상태인지 확인함
- [ ] 없는 경우 destructive mutation 없이 생성 가능한 보조 데이터만 추가함
- [ ] 보조 데이터 생성 후 알림 actor·친구 카드·캘린더 표시가 일치함

### 4.8 iPhone 17 Pro 교차 기기 회귀 결과

2026-08-31에 기존 `iPhone 13 mini`와 화면 크기·Safe Area가 다른 `iPhone 17 Pro`(iOS 26.5)에서 동일한 운영 심사 계정 회귀를 다시 수행했다.

- 최신 실제 저장소 `DutyparkTests`: `PASS (1,159/1,159; 0 FAIL)` — `/private/tmp/dutypark-alt17-unit-tests.log`
- 운영 API Release build: `PASS` — `/private/tmp/dutypark-alt17-release-build.log`
- 운영 심사 계정 핵심 UI: `PASS (12/12; 0 FAIL; 1,163.036s)` — `/private/tmp/dutypark-alt17-live-review-2.log`, `/private/tmp/dutypark-alt17-live-review-2.xcresult`
- UI 범위: 로그인, 9·10월 일정 재조회, logout·wrong password·guest·relogin, 일정/D-Day/Todo CRUD와 cleanup, 설정·사진/파일 picker 취소, 5개 tab·More, Calendar·Todo·Team safe navigation, 정책·테마·계정 삭제 취소, Social·알림·지원의 위험 confirmation 취소
- 최종 실제 저장소 Release install/launch: `PASS` — PID `13025`, 로그인 Home 확인
- 최종 clean Home: `PASS` — `ios/review-evidence/2026-08-31/final-release-iphone17pro-home.png` (1206×2622)
- Simulator CrashReporter: `PASS (Dutypark crash report 0건)`
- 자격 증명: test runner 환경에만 일시 주입했으며 실행 직후 두 xctestrun 파일에서 키를 제거하고 저장소·보고서·증거에 비밀값이 없음을 재확인했다.

첫 `build-for-testing`은 이전에 중단된 미완성 임시 확장 harness 두 파일이 `/private/tmp` 소스 복사본에 뒤늦게 남아 Swift compile이 실패했다. 저장소 제품 코드와 무관한 자동화 준비 실패로 분류했고 해당 임시 파일만 제거한 뒤 동일 명령이 성공했다. UI 실행 후 Xcode가 원본 simulator를 자동 종료해 첫 최종 install이 `CoreSimulator code 405 / Shutdown`으로 거절됐으나, 기기를 재부팅한 뒤 동일 Release install·launch가 성공했다. 두 사건 모두 제품 결함이나 앱 crash로 합산하지 않는다.

## 5. 기기·빌드·실행 매트릭스

| 순서 | 기기/OS | 구성/API | 목적 | 현재 상태 | 증거 |
|---:|---|---|---|---|---|
| 1 | iPhone 13 mini / iOS 26.5 | 최종 fixed Release / 운영 API | 기준 심사 계정 전수 실행 | build·exact simulator install/launch·clean Home·인증/guest 경계·safe navigation·일정/D-Day/Todo CRUD·9/10월 데이터 `PASS`; 확장 전수 진행 중 | `/private/tmp/dutypark-final-release-build.log`, `ios/review-evidence/2026-08-31/final-release-home-clean.png` |
| 1-A | iPhone 17 Pro / iOS 26.5 | 최종 fixed Release / 운영 API | 다른 화면 크기 교차 기기 회귀 | unit 1,159건·Release build·운영 UI 12건·install/launch·clean Home·CrashReporter `PASS` | `/private/tmp/dutypark-alt17-unit-tests.log`, `/private/tmp/dutypark-alt17-release-build.log`, `/private/tmp/dutypark-alt17-live-review-2.log`, `ios/review-evidence/2026-08-31/final-release-iphone17pro-home.png` |
| 2 | iPhone 13 mini / iOS 26.5 | Release / 운영 API / 로그인 상태 | force quit·재실행 세션 복구 | `NOT RUN` |  |
| 3 | iPhone 13 mini / iOS 26.5 | Release / 운영 API / 한국어 Light | 기본 심사 흐름 | 로그인·로그아웃·잘못된 비밀번호·guest guide/support/정책·재로그인·5개 tab `PASS` | `/private/tmp/dutypark-review-auth-guest-final-5.log` |
| 4 | iPhone 13 mini / iOS 26.5 | Release / 운영 API / 한국어 Dark/System | 테마·레이아웃 | Dark→System 전환 control `PASS`; Light 시각·전체 테마 회귀는 `NOT RUN` | `/private/tmp/dutypark-review-settings-picker-final-4.log` |
| 5 | iPhone 13 mini / iOS 26.5 | Release / 운영 API / English | 현지화 | `NOT RUN` |  |
| 6 | iPhone 13 mini / iOS 26.5 | Release / 운영 API / offline→online | 캐시·outbox·복구 | `NOT RUN` |  |

추가 해상도 실행은 기준 기기의 전수 검증 결과와 위험도를 보고 결정한다. 2026-08-28·29의 다른 해상도 결과는 이 표에 재사용하지 않는다.

## 6. 실제 심사 계정 전수 기능 체크리스트

현재 `PASS`는 2026-08-30~31 실행에서 확인된 결과만 뜻한다. 과거 자동 fixture 테스트 이름이나 기존 보고서의 PASS는 아래 항목을 자동으로 체크하지 않는다.

### 6.1 최초 실행·게스트·인증

- [ ] `AUTH-001` `NOT RUN` — cold launch에서 guest landing/login 화면 표시
- [ ] `AUTH-002` `BLOCKED` — 심사 계정 공개 member 67 guest 캘린더 진입. 비인증 `GET /api/members/67`가 `401`을 반환해 현재 visibility를 확인할 수 없음; 앱 결함으로 분류하지 않음
- [ ] `AUTH-003` `NOT RUN` — guest 월 이동·먼 월 선택·오늘 복귀
- [x] `AUTH-004` `PASS` — guest guide 진입·section 확인·뒤로가기
- [x] `AUTH-005` `PASS` — guest support 진입과 sign-in hint, 이용약관·개인정보처리방침 진입·복귀
- [x] `AUTH-006` `PASS` — 심사용 계정 정상 로그인 전용 UI test (15.349s)
- [ ] `AUTH-007` `NOT RUN` — 빈 이메일/빈 비밀번호 validation
- [x] `AUTH-008` `PASS` — 잘못된 비밀번호 오류 표시 및 비인증 상태 유지
- [ ] `AUTH-009` `NOT RUN` — 키보드 명시적 닫기와 저장 버튼 접근
- [ ] `AUTH-010` `NOT RUN` — remember-me 동작
- [ ] `AUTH-011` `NOT RUN` — Apple 로그인 진입·취소·복귀
- [ ] `AUTH-012` `NOT RUN` — Kakao 로그인 진입·취소·복귀
- [ ] `AUTH-013` `NOT RUN` — Naver 로그인 진입·취소·복귀
- [ ] `AUTH-014` `NOT RUN` — SSO signup draft 입력·취소 confirmation
- [x] `AUTH-015` `PASS` — 로그아웃 confirmation 취소 (safe-navigation 케이스)
- [x] `AUTH-016` `PASS` — 로그아웃 확인·guest landing 복귀
- [x] `AUTH-017` `PASS` — 정상 재로그인 후 인증 상태·5개 탭 복귀
- [ ] `AUTH-018` `NOT RUN` — force quit 후 세션 복구
- [ ] `AUTH-019` `BLOCKED` — 서버 세션 강제 만료/401을 실제 계정에서 재현할 방법 확인 전까지 보류

### 6.2 Home

- [x] `HOME-001` `PASS` — 로그인 상태 Home 화면 표시
- [x] `HOME-002` `PASS` — 최종 fixed Release Home에서 오늘 일정 `월말 일정 정리`와 근무 `OFF` 표시 확인
- [ ] `HOME-003` `NOT RUN` — 9월·10월 D-Day 카드 표시
- [ ] `HOME-004` `NOT RUN` — 고정 친구 카드 탭으로 친구 캘린더 진입
- [ ] `HOME-005` `NOT RUN` — 미고정 친구 카드 탭으로 친구 캘린더 진입
- [ ] `HOME-006` `NOT RUN` — 친구 카드 세로 스크롤과 캘린더 오픈 분리
- [ ] `HOME-007` `NOT RUN` — 친구 rail 가로 스크롤
- [ ] `HOME-008` `NOT RUN` — 친구 pin/unpin과 화면 위치 유지
- [ ] `HOME-009` `NOT RUN` — 친구 long-press reorder와 저장 결과
- [ ] `HOME-010` `NOT RUN` — 다수 친구 overflow와 lazy row 조작
- [ ] `HOME-011` `NOT RUN` — 알림 badge 표시
- [ ] `HOME-012` `NOT RUN` — notification dropdown 열기·닫기
- [ ] `HOME-013` `NOT RUN` — 알림 항목 탭으로 대상 화면 이동
- [x] `HOME-014` `PASS` — More 탭 진입과 전역 메뉴 표시 (safe-navigation 케이스)

### 6.3 Calendar·개인 일정

- [x] `CAL-001` `PASS` — Calendar 탭 진입 및 화면 표시
- [ ] `CAL-002` `NOT RUN` — 이전/다음 월 이동
- [x] `CAL-003` `PASS` — 월 선택기에서 2026-09 선택 및 9월 일정 재조회
- [x] `CAL-004` `PASS` — 월 선택기에서 2026-10 선택 및 10월 일정 재조회
- [ ] `CAL-005` `NOT RUN` — 오늘 복귀
- [x] `CAL-006` `PASS` — 9·10월 대상 날짜 선택과 일정 상세 영역 표시
- [ ] `CAL-007` `NOT RUN` — 일정·근무·Todo의 날짜 셀 동시 표시
- [ ] `CAL-008` `NOT RUN` — 친구/팀 비교 캘린더
- [x] `CAL-009` `PASS` — 10월 전체 공개 일정 생성·저장·재조회
- [x] `CAL-010` `PASS` — 10월 친구 공개 일정 생성·저장·재조회
- [x] `CAL-011` `PASS` — 10월 가족 공개 일정 생성·저장·재조회
- [x] `CAL-012` `PASS` — 10월 나만 보기 일정 생성·저장·재조회
- [x] `CAL-013` `PASS` — 종일 일정 생성·재조회
- [x] `CAL-014` `PASS` — 시작/종료 시간이 있는 일정 생성·재조회
- [x] `CAL-015` `PASS` — 날짜를 넘는 기간 일정 생성·재조회
- [ ] `CAL-016` `NOT RUN` — 제목·내용·긴 문구 입력
- [ ] `CAL-017` `NOT RUN` — 친구 태그 선택·검색·저장
- [x] `CAL-018` `PASS` — 9월 기존 일정 중복 회피 및 10월 일정 입력 후 즉시 표시
- [ ] `CAL-019` `NOT RUN` — 앱 재실행 후 일정 persistence
- [x] `CAL-020` `PASS` — live CRUD 일정 상세에서 생성한 일정만 열림
- [x] `CAL-021` `PASS` — live CRUD 일정 수정 후 운영 목록 재표시
- [ ] `CAL-022` `SKIP` — 심사 계정 최종 대표 일정의 UI 삭제 완료. 삭제 confirmation 진입·취소까지만 수행
- [ ] `CAL-023` `NOT RUN` — 같은 날 일정 순서 재정렬
- [ ] `CAL-024` `NOT RUN` — 일정 검색 성공 결과
- [ ] `CAL-025` `NOT RUN` — 일정 검색 빈 결과
- [ ] `CAL-026` `NOT RUN` — 검색 결과의 월 이동·상세 deep link
- [ ] `CAL-027` `NOT RUN` — 사진 첨부 picker 진입·권한 처리
- [ ] `CAL-028` `NOT RUN` — 파일 첨부 picker 진입·잘못된 파일 오류
- [ ] `CAL-029` `NOT RUN` — 첨부 gallery 표시·개별 삭제 confirmation
- [ ] `CAL-030` `NOT RUN` — AI 일정 시간 파싱 동의 화면
- [ ] `CAL-031` `NOT RUN` — AI 동의 후 파싱 성공 또는 결과 표시
- [ ] `CAL-032` `NOT RUN` — AI 거부 후 수동 입력
- [ ] `CAL-033` `NOT RUN` — AI 실패 후 수동 입력
- [ ] `CAL-034` `NOT RUN` — 일정 금칙어 validation
- [ ] `CAL-035` `NOT RUN` — 빠른 근무 입력과 근무 유형 선택
- [ ] `CAL-036` `NOT RUN` — 월간 근무 batch/Excel picker 진입
- [ ] `CAL-037` `NOT RUN` — 잘못된/큰 batch 파일 오류
- [ ] `CAL-038` `NOT RUN` — 오프라인 캐시 월 조회
- [ ] `CAL-039` `NOT RUN` — 오프라인 일정 생성 outbox
- [ ] `CAL-040` `NOT RUN` — 온라인 복귀 동기화와 중복 생성 방지

### 6.4 D-Day

- [ ] `DDAY-001` `NOT RUN` — 기존 `가을 휴가 시작` D-Day 상세 조회
- [ ] `DDAY-002` `NOT RUN` — 기존 `팀 프로젝트 발표` D-Day 상세 조회
- [ ] `DDAY-003` `NOT RUN` — 9월/10월 카운트다운 숫자와 날짜 정확성
- [ ] `DDAY-004` `NOT RUN` — D-Day pin/unpin
- [ ] `DDAY-005` `NOT RUN` — public/private 상태 확인
- [ ] `DDAY-006` `NOT RUN` — D-Day 생성 validation
- [x] `DDAY-007` `PASS` — 임시 D-Day 생성 후 운영 목록 표시 및 reload 경로 확인 (대표 두 항목과 분리)
- [x] `DDAY-008` `PASS` — 임시 D-Day 수정 후 운영 목록 표시 및 reload 경로 확인
- [ ] `DDAY-009` `SKIP` — 심사 계정 대표 D-Day 최종 삭제. 삭제 sheet 진입·취소까지만 수행
- [ ] `DDAY-010` `NOT RUN` — 공개 D-Day 금칙어 validation
- [ ] `DDAY-011` `NOT RUN` — private D-Day 금칙어 예외 정책

### 6.5 Todo

- [x] `TODO-001` `PASS` — Todo 탭과 `TODO`·`IN_PROGRESS`·`DONE` 상태 컬럼 표시
- [ ] `TODO-002` `NOT RUN` — 빈 draft 생성 후 취소
- [x] `TODO-003` `PASS` — dirty Todo draft 취소·폐기 confirmation
- [ ] `TODO-004` `NOT RUN` — 제목·내용·마감일 입력
- [ ] `TODO-005` `NOT RUN` — 긴 텍스트 입력과 wrap
- [x] `TODO-006` `PASS` — 6건 생성 시 `TODO`·`IN_PROGRESS`·`DONE` 상태 선택
- [x] `TODO-007` `PASS` — 임시 Todo 상세 화면 열기
- [ ] `TODO-008` `NOT RUN` — 상세/수정 화면 상태 control 정책
- [x] `TODO-009` `PASS` — 임시 Todo 제목 수정 및 live 목록 재표시 (별도 force quit persistence는 미검증)
- [x] `TODO-010` `PASS` — Todo 탭 이탈 후 재진입 시 6건 상태·마감일 persistence
- [ ] `TODO-011` `NOT RUN` — 같은 컬럼 long-press reorder
- [x] `TODO-012` `PASS` — 임시 Todo를 `TODO`에서 `IN_PROGRESS`로 이동하고 상태 확인
- [ ] `TODO-013` `NOT RUN` — 스크롤과 drag 충돌 방지
- [ ] `TODO-014` `NOT RUN` — 태그 입력·표시
- [ ] `TODO-015` `NOT RUN` — 사진/파일 첨부·gallery
- [ ] `TODO-016` `SKIP` — 심사 계정 대표 Todo 최종 삭제. confirmation 진입·취소까지만 수행
- [ ] `TODO-017` `NOT RUN` — malformed/잘못된 ID가 crash를 일으키지 않음
- [ ] `TODO-018` `NOT RUN` — 오프라인 캐시 조회
- [ ] `TODO-019` `NOT RUN` — 오프라인 Todo 생성 outbox
- [ ] `TODO-020` `NOT RUN` — 온라인 복귀 동기화·중복 방지

### 6.6 Team·근무

- [x] `TEAM-001` `PASS` — Team 탭 진입 (safe-navigation 케이스)
- [ ] `TEAM-002` `NOT RUN` — 2026-09 팀 월 이동
- [ ] `TEAM-003` `NOT RUN` — 2026-10 팀 월 이동
- [ ] `TEAM-004` `NOT RUN` — 팀원별 근무 셀 표시
- [ ] `TEAM-005` `NOT RUN` — 근무 유형 이름·색상 표시
- [ ] `TEAM-006` `NOT RUN` — 팀원 캘린더 진입·뒤로가기
- [ ] `TEAM-007` `NOT RUN` — 팀 일정 생성
- [ ] `TEAM-008` `NOT RUN` — 팀 일정 수정·재조회
- [ ] `TEAM-009` `SKIP` — 심사 계정 대표 팀 일정 최종 삭제. confirmation 진입·취소까지만 수행
- [ ] `TEAM-010` `NOT RUN` — 관리자 Team 관리 진입
- [ ] `TEAM-011` `NOT RUN` — 팀 검색·상세
- [ ] `TEAM-012` `NOT RUN` — 멤버 목록·lead 표시
- [ ] `TEAM-013` `NOT RUN` — 근무 유형 숨김 confirmation
- [ ] `TEAM-014` `NOT RUN` — 근무 유형 복원
- [ ] `TEAM-015` `NOT RUN` — 패턴 저장 validation
- [ ] `TEAM-016` `NOT RUN` — batch/Excel 업로드 진입·오류
- [ ] `TEAM-017` `BLOCKED` — 권한 부족/서버 오류는 재현 조건 확인 전까지 보류
- [ ] `TEAM-018` `SKIP` — 팀 삭제·팀원 제거 최종 mutation

### 6.7 Social·친구·공유

- [x] `SOCIAL-001` `PASS` — 친구 관리 진입 (safe-navigation 케이스; 친구 mutation은 별도 미검증)
- [ ] `SOCIAL-002` `NOT RUN` — 친구 이름 검색
- [ ] `SOCIAL-003` `NOT RUN` — 친구 요청 전송 화면
- [ ] `SOCIAL-004` `NOT RUN` — 친구 요청 수락 UI
- [ ] `SOCIAL-005` `NOT RUN` — 친구 요청 거절 UI
- [ ] `SOCIAL-006` `SKIP` — 운영 친구 삭제 최종 제출
- [ ] `SOCIAL-007` `SKIP` — 운영 친구 차단 최종 제출
- [ ] `SOCIAL-008` `NOT RUN` — 차단 목록·해제 화면 진입
- [x] `SOCIAL-009` `PASS` — 친구 카드에서 친구 캘린더 진입·복귀
- [ ] `SOCIAL-010` `NOT RUN` — 친구 공개 일정 확인
- [ ] `SOCIAL-011` `NOT RUN` — 일정 신고 sheet·사유 validation까지만 확인
- [ ] `SOCIAL-012` `SKIP` — 운영 신고 최종 제출
- [ ] `SOCIAL-013` `NOT RUN` — 신고 sheet의 block toggle 상태 표시
- [ ] `SOCIAL-014` `NOT RUN` — 신고/차단 실패 시 상태 오인 없음
- [ ] `SOCIAL-015` `NOT RUN` — pinned friend reorder
- [ ] `SOCIAL-016` `NOT RUN` — overflow friend reorder
- [ ] `SOCIAL-017` `NOT RUN` — pin/more 버튼 plain tap과 drag 분리
- [ ] `SOCIAL-018` `NOT RUN` — 친구 프로필 사진과 fallback avatar

### 6.8 알림·지원

- [ ] `NOTIFY-001` `NOT RUN` — 알림 dropdown unread badge
- [ ] `NOTIFY-002` `NOT RUN` — 알림 센터 pushed navigation
- [ ] `NOTIFY-003` `NOT RUN` — unread 항목 읽음 처리
- [ ] `NOTIFY-004` `NOT RUN` — 전체 읽음
- [ ] `NOTIFY-005` `SKIP` — 심사 화면용 알림 전체 삭제
- [ ] `NOTIFY-006` `SKIP` — 심사 화면용 개별 알림 최종 삭제
- [ ] `NOTIFY-007` `NOT RUN` — 알림 딥링크
- [ ] `NOTIFY-008` `NOT RUN` — 빈 알림·load error·retry
- [ ] `NOTIFY-009` `BLOCKED` — 운영 APNs 실수신은 Simulator 제약 확인 전까지 보류
- [ ] `SUPPORT-001` `NOT RUN` — 문의 빈 입력 validation
- [ ] `SUPPORT-002` `NOT RUN` — 문의 긴 내용·금칙어 validation
- [ ] `SUPPORT-003` `NOT RUN` — 문의 제출 성공과 내 문의 목록
- [ ] `SUPPORT-004` `NOT RUN` — 문의 네트워크 오류·재시도
- [x] `SUPPORT-005` `PASS` — 내 신고 탭 진입 확인 (목록 내용·신고 생성은 별도 미검증)

### 6.9 More·설정·프로필

- [x] `SETTINGS-001` `PASS` — More 메뉴와 하단 탭의 주요 진입점 표시·탐색
- [x] `SETTINGS-002` `PASS` — My Info/프로필 정보 진입
- [ ] `SETTINGS-003` `NOT RUN` — 이름 변경과 재실행 persistence
- [ ] `SETTINGS-004` `NOT RUN` — 사진 선택·crop·업로드
- [ ] `SETTINGS-005` `SKIP` — 기존 심사 계정 사진 최종 삭제
- [ ] `SETTINGS-006` `NOT RUN` — 앱 버전 표시
- [ ] `SETTINGS-007` `NOT RUN` — 한국어/영어 전환 또는 Simulator 제약 기록
- [x] `SETTINGS-008` `PASS` — Dark→System 테마 control 변경 (Light 및 전체 화면 시각 회귀는 미검증)
- [ ] `SETTINGS-009` `NOT RUN` — 테마 재실행 persistence
- [ ] `SETTINGS-010` `NOT RUN` — 연결 계정 상태
- [ ] `SETTINGS-011` `NOT RUN` — 연결/해제 confirmation
- [ ] `SETTINGS-012` `NOT RUN` — Apple authorization revocation 안내
- [x] `SETTINGS-013` `PASS` — Settings에서 native guide 진입·복귀 (safe-navigation 케이스)
- [ ] `SETTINGS-014` `NOT RUN` — 이용약관 긴 문서
- [ ] `SETTINGS-015` `NOT RUN` — 개인정보처리방침 긴 문서
- [ ] `SETTINGS-016` `NOT RUN` — AI 일정 정책 긴 문서
- [ ] `SETTINGS-017` `NOT RUN` — 문의·신고 정책
- [ ] `SETTINGS-018` `PARTIAL` — 계정 삭제 화면 진입·취소 확인; ETA·보존 예외 문구는 미검증
- [ ] `SETTINGS-019` `SKIP` — 계정 삭제 최종 destructive action 및 완료 요청

### 6.10 관리자·대리 로그인

- [ ] `ADMIN-001` `NOT RUN` — 관리자 메뉴 노출 권한
- [ ] `ADMIN-002` `NOT RUN` — 회원 검색
- [ ] `ADMIN-003` `NOT RUN` — 회원 상세
- [ ] `ADMIN-004` `NOT RUN` — 회원 상태·세션 조회
- [ ] `ADMIN-005` `NOT RUN` — 비밀번호 초기화 화면 진입
- [ ] `ADMIN-006` `NOT RUN` — 대리 로그인 진입·banner
- [ ] `ADMIN-007` `NOT RUN` — 대리 화면에서 로그아웃·원계정 복귀
- [ ] `ADMIN-008` `NOT RUN` — 팀 검색·상세
- [ ] `ADMIN-009` `NOT RUN` — 확인 모달·빈 결과·권한 오류
- [ ] `ADMIN-010` `SKIP` — 관리자 회원/팀 삭제·제거 mutation

### 6.11 공통 품질·비기능

- [ ] `QUALITY-001` `NOT RUN` — 주요 버튼 최소 44×44pt
- [ ] `QUALITY-002` `NOT RUN` — VoiceOver label·identifier
- [ ] `QUALITY-003` `NOT RUN` — Safe Area·노치·Dynamic Island
- [ ] `QUALITY-004` `NOT RUN` — 탭바·홈 indicator 겹침 없음
- [ ] `QUALITY-005` `NOT RUN` — 키보드가 입력/저장 버튼을 가리지 않음
- [ ] `QUALITY-006` `NOT RUN` — 긴 한국어·영어 문구 wrap
- [ ] `QUALITY-007` `NOT RUN` — Dynamic Type 큰 글자
- [ ] `QUALITY-008` `NOT RUN` — Light/Dark 시각 확인
- [ ] `QUALITY-009` `NOT RUN` — foreground/background 전환
- [ ] `QUALITY-010` `NOT RUN` — force quit/relaunch
- [ ] `QUALITY-011` `NOT RUN` — 느린 네트워크 loading/재시도
- [ ] `QUALITY-012` `NOT RUN` — offline 상태의 캐시/생성 정책
- [ ] `QUALITY-013` `NOT RUN` — network recovery
- [ ] `QUALITY-014` `NOT RUN` — HTTP 401/4xx/5xx 오류 UI
- [ ] `QUALITY-015` `NOT RUN` — 중복 저장·중복 알림 없음
- [x] `QUALITY-016` `PASS` — 이번 simulator CrashReporter에서 Dutypark crash report 0건
- [x] `QUALITY-017` `PASS` — XCTest 접근성/runner 실패 이력과 실제 제품 결함·crash를 분리 기록
- [x] `QUALITY-018` `PASS` — 제출 보고서·증거 이미지·공유 로그 경로에서 심사용 비밀번호 미노출 확인
- [ ] `QUALITY-019` `NOT RUN` — 9월·10월 데이터 서버/API/UI 정합성

### 6.12 추가 live 실행 매핑

아래 ID는 기존 기능 항목을 과대 확장하지 않기 위한 실행 단위다. safe-navigation aggregate의 최초 실행은 4건 중 3건 PASS·1건 자동화 실패였고, 실패 케이스는 최종 단독 재실행으로 PASS를 확정했다. 그러므로 아래 네 행을 합산해 최종 4건 PASS로 기록하되, 최초 aggregate 자체를 4/4 PASS로 표현하지 않는다.

| ID | 범위 | 상태 | 증거·범위 제한 |
|---|---|---|---|
| `SAFE-NAV-001` | Primary tabs 및 More root/destination 진입 | `PASS (77.392s)` | `/private/tmp/dutypark-review-safe-navigation.log`; 저장 mutation 없음 |
| `SAFE-NAV-002` | Calendar·Todo·Team 진입/상세 탐색, 저장 없이 복귀 | `PASS (99.795s)` | `/private/tmp/dutypark-review-safe-navigation-final.log`, `/tmp/dutypark-review-safe-navigation-final.xcresult`; 초기 자동화 재시도 실패는 Section 7.1 이력 참조 |
| `SAFE-NAV-003` | Settings·정책·Theme·계정 삭제 화면 진입 및 취소 | `PASS (263.993s)` | `/private/tmp/dutypark-review-safe-navigation.log`; 계정 삭제 최종 mutation 없음 |
| `SAFE-NAV-004` | Social·Notifications·Support 진입 및 위험 confirmation 취소 | `PASS (110.734s)` | `/private/tmp/dutypark-review-safe-navigation.log`; 친구 삭제/차단·신고 최종 제출 없음 |
| `CAL-041` | 운영 API 임시 일정 create/detail/edit/delete lifecycle | `PASS (47.735s)` | `/private/tmp/dutypark-review-schedule-crud-retry.log`; `/tmp/dutypark-review-schedule-crud-retry.xcresult`; 임시 일정 cleanup 완료 |
| `DDAY-012` | 운영 API 임시 D-Day create/edit/delete-confirm/reload lifecycle | `PASS (51.228s)` | `/private/tmp/dutypark-review-dday-crud-final-fixed.log`; `/tmp/dutypark-review-dday-crud-final-fixed.xcresult`; 대표 D-Day와 분리·임시 cleanup 완료 |
| `TODO-021` | 운영 API 임시 Todo create/detail/edit/status-move/delete lifecycle | `PASS (100.099s)` | `/private/tmp/dutypark-review-todo-crud.log`; `/tmp/dutypark-review-todo-crud.xcresult`; 대표 Todo 6건 재확인 |
| `SETTINGS-020` | Dark→System, AI 동의 취소, 사진/파일 picker open/cancel, 미저장 Todo 폐기 | `PASS (47.865s)` | `/private/tmp/dutypark-review-settings-picker-final-4.log`; `/tmp/dutypark-review-settings-picker-final-4.xcresult`; 실제 upload·Light 시각 검증 없음 |

## 7. 자동 검증과 운영 실검증의 구분

| 범위 | 의미 | 현재 보고서 집계 |
|---|---|---|
| `DutyparkTests` | 모델·ViewModel·오프라인·정책 단위 검증 | 기존 문서 결과는 참고. 운영 계정 PASS로 합산하지 않음 |
| `DutyparkUITests` fixture | 고정 fixture를 이용한 화면·레이아웃 검증 | 기존 문서 결과는 참고. 운영 데이터 동작을 대신하지 않음 |
| 최신 fixed Release build/install/launch | 운영 API를 포함한 현재 바이너리의 build와 exact simulator 실행 | **PASS** — `/private/tmp/dutypark-final-release-build.log`, `ios/review-evidence/2026-08-31/final-release-home-clean.png` |
| 심사용 계정 인증·guest 경계 | 5개 tab, logout, wrong-password, guest guide/support/policies, relogin | **PASS (197.339s)** — `/private/tmp/dutypark-review-auth-guest-final-5.log` |
| 운영 계정 safe navigation | 네 가지 읽기/취소 중심 navigation case | **4개 케이스 PASS** — Section 6.12. 최초 aggregate 1건 실패 후 단독 재실행 |
| 운영 계정 CRUD | 일정·D-Day·Todo 임시 레코드 lifecycle | **PASS** — Section 6.12; 임시 데이터 cleanup 완료 |
| 운영 계정 전수 UI/서버 persistence | 본 보고서의 핵심 실행 | 9·10월 대표 데이터·근무표 보존·Todo 6건 및 핵심 CRUD PASS; 확장 전수 진행 중 |
| 최신 `DutyparkTests` | iOS unit/model/policy regression | **1,159 PASS / 0 FAIL** — `/private/tmp/dutypark-final-unit-tests.log` |
| offline/network recovery | 실제 Simulator 상태 전환 | `NOT RUN` |
| CrashReporter scan | 이번 simulator 실행의 Dutypark crash report 존재 여부 | **PASS (0건)** — crash report 경로 scan; 전체 hang/runner log 판정은 별도 |
| crash/log inspection | 현재 실행의 hang·무한 로딩·전체 runner 로그 확인 | `NOT RUN` — CrashReporter 0건만으로 대체하지 않음 |

자동 테스트의 PASS를 실제 운영 계정의 기능 PASS로 바꾸지 않는다. 반대로 운영 계정에서 발견한 결함은 fixture PASS 여부와 무관하게 이 보고서에 기록한다.

### 7.1 운영 데이터 자동화 보정 기록

Calendar/Todo 데이터 입력의 앞선 실패는 앱 코드 결함이 아니라 XCTest 접근성/제스처 자동화 문제로 분류했다. 반면 D-Day 삭제 성공 뒤 stale dismiss/잠금 경쟁은 제품 코드 결함으로 확인되어 수정했다. 두 종류의 이력을 섞지 않으며, 운영 앱의 최종 경로는 보정된 자동화와 수정된 Release로 각각 재검증했다.

| 대상 | 관찰된 문제 | 자동화 보정 | 제품 코드 수정 | 결과 |
|---|---|---|---|---|
| Calendar 일정 seed | 일정 editor의 외부 ScrollView 안에 중첩 ScrollView가 있어 일반 swipe가 날짜/저장 컨트롤까지 전달되지 않음. 시스템 DatePicker 날짜 버튼에는 안정적인 identifier가 없고 locale 형식 label만 노출됨 | modal 외부 좌측 여백에서 outer scroll을 직접 드래그하고, 한국어/영어 locale 날짜 label과 월 이동 버튼을 함께 탐색 | 없음 | `ReviewCalendarDataUITests` 1/1 PASS |
| Todo seed | Todo editor의 nested ScrollView 때문에 마감일 toggle을 단순 scroll로 hittable하게 만들 수 없음. 시스템 DatePicker의 접근성 label도 locale·런타임에 따라 달라짐 | modal 외부 좌측 여백에서 outer scroll을 직접 드래그하고, 여러 locale 날짜 label·월 이동을 순차 탐색 | 없음 | `ReviewTodoDataUITests` seed/reentry 1/1 PASS |
| D-Day 삭제 | DELETE 성공 후 stale presentation dismiss와 잠금 상태가 경쟁하여 confirmation/modal 상태가 남거나 카드 재조회 assertion이 흔들림 | 재현 로그와 confirmation hierarchy를 분리하고 제품 dismiss 경로를 focused unit으로 고정 | `CalendarView.swift`에 delete-success callback·yield 후 dismiss·성공 상태 기반 dismissability 반영 | focused 2건 PASS 및 수정 Release CRUD PASS (51.228s) |

Calendar/Todo의 자동화 보정은 테스트 helper에만 적용됐으며 운영 앱의 UI·API·데이터 계약을 수정한 것이 아니다. D-Day 행은 별도의 실제 제품 수정이다. `UIAccessibilityLoaderWebShared` 중복 클래스와 `DebuggerVersionStore` 경고는 Simulator/IDE 진단으로 별도 기록하고 제품 crash로 분류하지 않는다.

## 8. 실행 로그

| 시각(KST) | 기기/빌드 | 시나리오 | 결과 | 증거 | 결함 |
|---|---|---|---|---|---|
| 2026-08-30 | iPhone 13 mini / Release / 운영 API | Release build·install | `PASS` | 초기 Release 운영 API build 결과 | 없음 확인 중 |
| 2026-08-30 23:56–23:57 | iPhone 13 mini / Release / 운영 API | 심사용 계정 login-only 및 5개 primary tab smoke | `PASS` | `/private/tmp/dutypark-review-login-smoke-retry.log` | 제품 결함 없음 확인 중 |
| 2026-08-30 | iPhone 13 mini / 로그인 상태 | Home 화면 확인 | `PASS` | login smoke 로그의 `screen.home` 및 탭 전환 | 없음 확인 중 |
| 2026-08-31 00:05–00:08 | iPhone 13 mini / Release / 운영 API | 9·10월 일정 5건씩 입력/중복 회피 및 서버-backed 재조회 | `PASS (154.603s)` | `/private/tmp/dutypark-review-calendar-data-final.log` | 자동화 보정으로 분류 |
| 2026-08-31 00:05–00:08 | iPhone 13 mini / Release / 운영 API | 9·10월 populated 근무표 보존 확인 | `PASS` | `/private/tmp/dutypark-review-calendar-data-final.log`의 `REVIEW_DUTY_SKIP_POPULATED` 두 건 | 덮어쓰기 없음 |
| 2026-08-31 00:25–00:31 | iPhone 13 mini / Release / 운영 API | 상태·마감일별 Todo 6건 입력 및 Todo 탭 재진입 재조회 | `PASS (345.489s)` | `/private/tmp/dutypark-review-todo-seed-final-5.log` | 자동화 보정으로 분류 |
| 2026-08-31 00:31–00:33 | iPhone 13 mini / Release / 운영 API | 임시 Todo create/detail/edit/status-move/delete lifecycle | `PASS (100.099s)` | `/private/tmp/dutypark-review-todo-crud.log` | 임시 레코드 cleanup 완료 |
| 2026-08-31 00:33–00:42 | iPhone 13 mini / Release / 운영 API | safe-navigation 4개 케이스 aggregate | `RESOLVED` | `/private/tmp/dutypark-review-safe-navigation.log`; 3 PASS·1 자동화 실패 후 단독 재실행 | 제품 결함 아님. 최종 케이스 증거는 아래 행 |
| 2026-08-31 00:46–00:48 | iPhone 13 mini / Release / 운영 API | Calendar·Todo·Team safe-navigation 재실행 | `PASS (99.795s)` | `/private/tmp/dutypark-review-safe-navigation-final.log` | 초기 selector/scroll 실패 보정 |
| 2026-08-31 01:28–01:29 | iPhone 13 mini / Release / 운영 API | 임시 일정 create/detail/edit/delete lifecycle | `PASS (47.735s)` | `/private/tmp/dutypark-review-schedule-crud-retry.log` | 임시 레코드 cleanup 완료; 잔여 prefix는 후속 cleanup에서 재확인 |
| 2026-08-31 01:31–01:32 | iPhone 13 mini / Debug / iOS unit | D-Day dismissal 정책 focused 2건 | `PASS` | `/private/tmp/dutypark-dday-fix-focused-2.log` | 제품 수정 focused GREEN |
| 2026-08-31 01:33–01:34 | iPhone 13 mini / Release / 운영 API | 수정 후 임시 D-Day create/edit/delete/reload | `PASS (51.228s)` | `/private/tmp/dutypark-review-dday-crud-final-fixed.log` | 이전 stale dismiss/잠금 제품 결함 수정 후 통과 |
| 2026-08-31 01:46–01:46 | iPhone 13 mini / Release / 운영 API | Dark→System·AI consent cancel·photo/file picker cancel·unsaved Todo discard | `PASS (47.865s)` | `/private/tmp/dutypark-review-settings-picker-final-4.log` | 실제 upload 없음 |
| 2026-08-31 02:00–02:03 | iPhone 13 mini / Release / 운영 API | 5개 tab·logout·wrong password·guest guide/support/terms/privacy·relogin | `PASS (197.339s)` | `/private/tmp/dutypark-review-auth-guest-final-5.log` | guest public calendar은 별도 401 BLOCKED |
| 2026-08-31 | iPhone 13 mini / Debug / iOS unit | 최신 `DutyparkTests` 전체 | `PASS (1,159/1,159; 0 FAIL)` | `/private/tmp/dutypark-final-unit-tests.log` | unit 결과만으로 UI crash 0을 대체하지 않음 |
| 2026-08-31 | iPhone 13 mini / Release / 운영 API | D-Day 수정 포함 최종 Release build·exact simulator install/launch | `PASS` | `/private/tmp/dutypark-final-release-build.log`, `ios/review-evidence/2026-08-31/final-release-home-clean.png` | clean Home·로그인 상태·임시 일정 부재 확인 |
| 2026-08-31 | iPhone 13 mini / Release / 운영 API | 과거 임시 일정 prefix-only cleanup 및 최종 화면 재확인 | `PASS` | `/private/tmp/dutypark-review-temp-schedule-cleanup.log`, `ios/review-evidence/2026-08-31/final-release-home-clean.png` | 대표 일정 보존, `심사 검증 임시...` 잔여 없음 |
| 2026-08-31 | iPhone 13 mini / Simulator CrashReporter | Dutypark crash report 경로 scan | `PASS (0건)` | Simulator CrashReporter 경로 scan 결과 | 이번 simulator 범위; hang/전체 runner log는 별도 |
| 2026-08-31 | guest public calendar / member 67 | 비인증 공개 캘린더 접근 | `BLOCKED` | 비인증 `GET /api/members/67` → `401` 관찰; 별도 HTTP probe artifact 미기록 | 현재 visibility 미확인. 앱 결함으로 분류하지 않음 |
| 2026-08-31 이후 | iPhone 13 mini / 운영 계정 | 전수 기능 검증 | 진행 중 | 아래 시나리오별로 추가 |  |

예정 artifact 경로 예시:

- `/private/tmp/dutypark-review-20260830/`
- `/private/tmp/dutypark-review-20260830/screenshots/`
- `/private/tmp/dutypark-review-20260830/logs/`
- `/private/tmp/dutypark-review-20260830/*.xcresult`

실제 경로를 확보하기 전에는 예시 경로를 증거 링크로 간주하지 않는다. 각 결과에는 기기, OS, build/source, API 환경, 시각, 시나리오 ID를 함께 기록한다. 위 실행 로그와 결과 번들은 현재 실행의 실제 증거이며, 임시 테스트 원본은 `/private/tmp/dutypark-ios-review-current.oP4X3K/DutyparkUITests/ReviewCalendarDataUITests.swift`, `/private/tmp/dutypark-ios-review-current.oP4X3K/DutyparkUITests/ReviewTodoDataUITests.swift`, `/private/tmp/dutypark-ios-review-current.oP4X3K/DutyparkUITests/ReviewLiveCRUDUITests.swift`, `/private/tmp/dutypark-ios-review-current.oP4X3K/DutyparkUITests/ReviewSafeNavigationUITests.swift`, `/private/tmp/dutypark-ios-review-current.oP4X3K/DutyparkUITests/ReviewLiveAuthenticationAndGuestUITests.swift`다.

## 9. 데이터 생성·검증 실행 기록

| 시각 | 계획 ID | 동작 | 서버 ID | 앱 재실행 확인 | API 재조회 | 상태 |
|---|---|---|---|---|---|---|
|  |  | 실행 전 D-Day 중복 조회 |  |  |  | `NOT RUN` |
| 2026-08-31 | `CAL-SEP-*` | 9월 일정 5건 입력 시도, 기존 항목 중복 회피, 월 이동 후 재조회 | 로그에 미기록 | 월 이동 후 재조회 | 서버-backed reload 확인 | `PASS` |
| 2026-08-31 | `CAL-OCT-*` | 10월 일정 5건 입력, 월 이동 후 재조회 | 로그에 미기록 | 월 이동 후 재조회 | 서버-backed reload 확인 | `PASS` |
|  | `TEAM-CAL-*` | 팀 일정 생성 |  |  |  | `NOT RUN` |
| 2026-08-31 | `DUTY-*` | 9·10월 근무표 populated 상태 확인, 전체 월 덮어쓰기 생략 | 로그에 미기록 | 보존 확인 | 월 상태 확인 | `PASS` |
| 2026-08-31 | `TODO-*` | `TODO`·`IN_PROGRESS`·`DONE` 상태별 Todo 6건 생성 및 탭 재진입 | 로그에 미기록 | 탭 이탈·재진입 | 재진입 후 목록/마감일 확인 | `PASS` |
| 2026-08-31 | `CAL-041` | 현재 날짜 임시 일정 create/edit/delete | 로그에 미기록 | 삭제 후 목록 부재 | live 목록 확인 | `PASS` |
| 2026-08-31 | `DDAY-012` | 임시 D-Day create/edit/delete/reload | 로그에 미기록 | Calendar 재진입 후 카드 부재 | reload 경로 확인 | `PASS` |
| 2026-08-31 | `TODO-021` | 임시 Todo create/edit/status-move/delete 후 대표 6건 재확인 | 로그에 미기록 | 삭제 후 대표 6건 확인 | live 목록 확인 | `PASS` |
| 2026-08-31 | `CLEANUP-001` | 과거 `심사 검증 임시...` 일정 prefix-only cleanup 및 최종 clean Home 확인 | 로그에 미기록 | 대표 일정 유지·임시 일정 부재 | `/private/tmp/dutypark-review-temp-schedule-cleanup.log` 및 `ios/review-evidence/2026-08-31/final-release-home-clean.png` | `PASS` |
|  |  | 최종 9월/10월 서버·앱 정합성 대조 |  |  |  | `NOT RUN` |

최종 데이터 판정 전 확인할 항목:

- [ ] 9월 월 화면에서 일정·근무·Todo·D-Day가 모두 의도한 위치에 표시됨
- [ ] 10월 월 화면에서 일정·근무·Todo·D-Day가 모두 의도한 위치에 표시됨
- [ ] 앱 force quit/relaunch 뒤 같은 데이터가 유지됨
- [ ] 서버 API 재조회 결과와 앱 표시가 일치함
- [ ] 기존 데이터의 ID·digest가 변하지 않음
- [ ] 동일한 기존 D-Day 두 개가 중복 생성되지 않음
- [ ] 계획한 생성 항목에 orphan·중복 row가 없음
- [ ] 알림 count와 실제 목록이 일치함
- [ ] 친구·팀 관계와 카드·캘린더 표시가 일치함
- [x] fixed Release clean Home에서 로그인 상태와 과거 임시 일정 부재를 확인함
- [x] 사용자 요청에 따라 심사 계정용 대표 데이터는 cleanup하지 않고 보존하며, 임시 CRUD 데이터만 cleanup함

## 10. 결함·수정·재검증

실행 중 문제가 발견되면 제품 결함, 테스트 harness 결함, 외부 서비스/Simulator 제약을 분리한다. 제품 동작 변경이 필요한 경우 focused RED를 먼저 보존하고 최소 수정 후 focused GREEN 및 관련 회귀를 기록한다.

| ID | 심각도 | 시나리오 | 재현 단계 | 기대/실제 | 증거 | 수정 | focused 재검증 | 회귀 | 상태 |
|---|---|---|---|---|---|---|---|---|---|
| REVIEW-001 | S3 | Calendar/Todo 데이터 자동화 | 중첩 ScrollView에서 일반 swipe와 system DatePicker label 조회 | 제품 UI가 실패한 것이 아니라 XCTest가 저장/날짜 control을 안정적으로 찾지 못함 | `/private/tmp/dutypark-review-calendar-data-final.log`, `/private/tmp/dutypark-review-todo-seed-final-5.log`, 초기 retry logs | modal 외부 좌측 드래그·locale label fallback을 test helper에만 적용 | Calendar 1/1, Todo seed/reentry 1/1 PASS | 운영 앱/API 변경 없음 | `RESOLVED` |
| REVIEW-002 | S2 | D-Day delete success 후 modal dismiss | 임시 D-Day DELETE 성공 뒤 화면 전환·reload | 기대: confirmation/modal 닫힘과 카드 제거. 실제: stale presentation dismiss와 잠금 상태가 경쟁하여 modal/card assertion이 남음 | `/private/tmp/dutypark-review-dday-crud-final.log`, `/private/tmp/dutypark-review-dday-crud-final-2.log`, `/private/tmp/dutypark-review-dday-crud-final-3.log`, `/private/tmp/dutypark-review-dday-crud-final-4.log`, `/private/tmp/dutypark-review-dday-crud-pass.log`, `/private/tmp/dutypark-review-dday-confirm-debug-2.log` | `ios/Dutypark/Features/Calendar/CalendarView.swift`에 delete-success callback·yield 후 dismiss·성공 상태 기반 dismissability 반영 | `CalendarFeatureTests.testDDayDeleteSuccessAuthorizesThenYieldsBeforeDismissingPresentation`, `testDDayModalCanDismissAfterDeleteSucceedsWhileConfirmationRouteIsStillActive` 2건 PASS — `/private/tmp/dutypark-dday-fix-focused-2.log` | 수정 Release 운영 CRUD create/edit/delete/reload `PASS (51.228s)` — `/private/tmp/dutypark-review-dday-crud-final-fixed.log` | `RESOLVED` |
| REVIEW-003 | S3/외부 제약 | guest public calendar / member 67 | 비인증 상태에서 공개 member endpoint 접근 | 앱 오류로 확정하지 않음. 비인증 `GET /api/members/67`가 `401`을 반환해 현재 visibility와 공개 캘린더를 실행할 수 없음 | 2026-08-31 HTTP probe 관찰; 별도 artifact 미기록 | 제품 수정 없음 | `BLOCKED`; 인증 guest flow 자체는 `/private/tmp/dutypark-review-auth-guest-final-5.log`에서 PASS | — | `BLOCKED` |

분류 원칙:

- `S1`: 앱 crash, 데이터 유실, 로그인 불가, 계정·권한 경계 우회
- `S2`: 핵심 기능 실패, 잘못된 저장/표시, 심사 흐름 차단
- `S3`: 비핵심 UI·문구·접근성·테스트 환경 문제
- Simulator의 `UIAccessibilityLoaderWebShared`, debugger version 등 시스템 진단은 제품 crash로 단정하지 않고 로그와 함께 분류
- 결함이 없어도 crash log·runner log를 확인하기 전에는 `QUALITY-016`을 PASS로 표시하지 않음

## 11. 미검증·잔여 위험

| 항목 | 현재 상태 | 사유 | 제출 영향 | 후속 조치 |
|---|---|---|---|---|
| 운영 계정 전수 기능 | 진행 중 | 인증/guest 경계·safe navigation·일정/D-Day/Todo CRUD·9·10월 데이터·fixed Release install까지 PASS | 높음 | 확장 checklist와 전체 데이터 정합성/오프라인/외부 서비스 항목 실행 |
| 2026-09/10 일정 | `PASS` | 각 5건을 입력 또는 중복 회피하고 server-backed reload로 재조회 | 중간 | 9·10월 대표 항목 자체의 수정·삭제, 친구 태그·검색은 별도 실행 |
| 2026-09/10 근무표 | `PASS` | 이미 populated 상태여서 덮어쓰지 않고 보존 확인 | 중간 | 셀 상세·비교·관리자 기능은 별도 실행 |
| Todo 6건 및 임시 Todo CRUD | `PASS` | 세 상태·마감일 seed/reentry와 임시 create/detail/edit/move/delete 통과, 임시 데이터 cleanup | 중간 | drag·첨부·오프라인은 별도 실행 |
| 임시 일정 CRUD | `PASS` | 운영 API에서 create/detail/edit/delete와 임시 cleanup 확인 | 중간 | 9·10월 대표 일정 수정·삭제는 별도 실행 |
| 임시 D-Day CRUD | `PASS` | 제품 수정 후 create/edit/delete/reload 통과, 임시 cleanup 확인 | 중간 | 대표 D-Day 두 건의 상세·중복 snapshot은 별도 실행 |
| D-Day stale dismiss/잠금 경쟁 | `RESOLVED` | 제품 코드 수정, focused 2건·수정 Release CRUD·최종 install/launch PASS | 낮음 | 확장 regression에서 재발 여부만 확인 |
| Safe navigation 4개 케이스 | `PASS` | 3개는 aggregate에서 PASS, 실패 케이스는 최종 단독 재실행 PASS | 중간 | 각 기능의 deep CRUD/오류/오프라인은 별도 실행 |
| 인증·guest 경계 | `PASS` | logout·wrong password·guest guide/support/terms/privacy·relogin PASS | 중간 | guest public calendar member 67은 401로 BLOCKED |
| Guest public calendar / member 67 | `BLOCKED` | 비인증 `GET /api/members/67`가 401; 현재 visibility 미확인 | 중간 | 서버 공개 endpoint/권한 설정 확인 후 재시도; 앱 결함으로 단정하지 않음 |
| 최신 DutyparkTests | `PASS` | 1,159 PASS / 0 FAIL | 낮음 | UI/실기기·crash evidence는 별도 |
| 앞선 Calendar/Todo UI 자동화 실패 | `RESOLVED` | 중첩 ScrollView·시스템 DatePicker 접근성 처리 문제로 재분류 | 낮음 | 자동화 helper 보정 결과 유지 |
| 과거 임시 일정 잔여 | `RESOLVED` | clean Home에서 발견한 `심사 검증 임시...` 1건을 prefix-only cleanup 후 최종 화면에서 부재 확인 | 낮음 | `/private/tmp/dutypark-review-temp-schedule-cleanup.log`와 clean Home screenshot 보존 |
| 이번 simulator CrashReporter | `PASS` (0건) | Dutypark crash report가 발견되지 않음 | 낮음 | 이번 simulator 범위의 결과이며 hang/전체 runner log와 구분 |
| 계정 최종 삭제 | `SKIP` | 제출 계정 보존 필요 | 높음 | disposable 계정으로 별도 검증 |
| 팀원 제거/팀 삭제 | `SKIP` | 복구 비용·심사 데이터 보존 | 중간 | 안전 계정 확보 후 검증 |
| 친구 차단/삭제 | `SKIP` | 친구·공유 상태 보존 | 중간 | 안전 계정 확보 후 검증 |
| 신고 최종 제출 | `SKIP` | 운영 신고 record 생성 방지 | 중간 | validation·취소까지만 확인 |
| OAuth 완료 | `NOT RUN` | 제3자 계정·외부 서비스 의존 | 중간 | 취소·복귀 우선 검증 |
| APNs 실수신 | `BLOCKED` | Simulator 환경 제약 | 중간 | 실기기/운영 entitlement 별도 확인 |
| 오프라인 실네트워크 | `NOT RUN` | 본 전수 흐름 후 실행 예정 | 중간 | 캐시·outbox·복구를 별도 기록 |
| 최종 fixed Release install/launch | `PASS` | exact `iPhone 13 mini`에 설치·실행하고 로그인 Home 및 임시 일정 부재를 clean screenshot으로 확인 | 낮음 | `ios/review-evidence/2026-08-31/final-release-home-clean.png` 유지 |
| 인증 만료/401 | `BLOCKED` | 세션 만료 재현 조건 미확정 | 중간 | 안전한 만료 fixture 또는 서버 지원 필요 |

## 12. 최종 제출 판정

최종 판정은 전수 checklist와 데이터 정합성·crash 확인이 끝난 뒤 갱신한다.

- 판정: `조건부 진행 중 — READY 아님`
- 수정 D-Day를 포함한 Release 운영 API build: `PASS` — `/private/tmp/dutypark-final-release-build.log`
- 심사용 계정 인증·5개 primary tab·logout·wrong password·guest guide/support/terms/privacy·relogin: `PASS (197.339s)`
- 로그인 상태 Home: `PASS`
- Safe navigation 4개 케이스: `PASS` — 초기 aggregate 1건은 자동화 실패 후 최종 단독 재실행
- 2026년 9월 일정 5건: `PASS`
- 2026년 10월 일정 5건: `PASS`
- 2026년 9·10월 근무표: `PASS — populated 상태 보존, 덮어쓰기 없음`
- Todo 6건 상태·마감일·탭 재진입: `PASS (345.489s)`
- 임시 Todo CRUD: `PASS (100.099s)` — cleanup 완료
- 임시 일정 CRUD: `PASS (47.735s)` — cleanup 완료
- 임시 D-Day CRUD/reload: `PASS (51.228s)` — 제품 수정 및 focused 2건 PASS 후 검증
- 설정·picker·미저장 Todo 폐기: `PASS (47.865s)` — Dark→System 범위
- 최신 `DutyparkTests`: `PASS (1,159/1,159; 0 FAIL)`
- Guest public calendar / member 67: `BLOCKED` — 비인증 `GET /api/members/67` 401; 앱 결함으로 분류하지 않음
- 최종 fixed Release exact simulator install/launch: `PASS` — `xcrun simctl`, PID 71599/72369; clean Home `ios/review-evidence/2026-08-31/final-release-home-clean.png` (1080×2340)
- iPhone 17 Pro 교차 기기 회귀: `PASS` — unit `1,159/1,159`, 운영 UI `12/12`, Release build/install/launch, clean Home, CrashReporter 0건
- iPhone 17 Pro 최종 증거: `ios/review-evidence/2026-08-31/final-release-iphone17pro-home.png` (1206×2622)
- 과거 임시 일정 prefix-only cleanup: `PASS` — `/private/tmp/dutypark-review-temp-schedule-cleanup.log`; 최종 clean Home에서 부재 확인
- 이번 simulator CrashReporter scan: `PASS (Dutypark report 0건)`
- 실제 운영 계정 전수 기능: `진행 중`
- 앱 crash report: `PASS (이번 simulator 범위 0건)`; hang·전체 runner log: `NOT RUN`
- 미해결 S1/S2 결함: 현재 실행 범위에서 제출 차단 결함 없음; 확장 전수 전 최종 판정 보류
- destructive 기능: 최종 제출 계정 보호를 위해 `SKIP`
- 최종 데이터 cleanup: 대표 9·10월 데이터는 보존하고 임시 CRUD 데이터만 cleanup
- core reviewer path: `READY (조건부)` — guest public calendar 401 BLOCKED 및 확장 미검증 항목은 잔여 위험으로 유지

전체 최종 `READY` 판정은 남은 전수·crash/log·데이터 정합성·외부 서비스 항목을 완료한 뒤에만 갱신한다. 현재는 core reviewer path만 조건부 READY로 판정하며, 이 보고서는 Apple의 실제 심사 승인 자체를 의미하지 않는다.
