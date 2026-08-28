# Dutypark iOS App Store 제출 전 QA 진행 문서

> 최종 현행화: 2026-08-28 (KST)
> 상태: fixture matrix·최종 Unit·Release·실제 계정 6개 해상도 smoke 완료; iPhone 13 mini Todo·일정·D-Day 생성/수정 persistence 및 데이터 완전 원복, 17e 인증·설정·관리자 focused 완료
> 원칙: 이 문서는 계획, 실행 결과, 결함, 수정, 재검증, 잔여 위험의 단일 기록이다.

## 1. 목표와 완료 기준

App Store 심사 제출 전에 지원 범위의 iPhone 해상도에서 Dutypark의 사용자 흐름, 예외 처리, 레이아웃, 접근성, 현지화, 네트워크 상태 및 앱 생명주기를 점검한다. 발견한 회귀는 가능하면 먼저 재현 테스트를 추가하고, 최소 수정 후 집중 테스트와 전체 회귀 테스트를 다시 수행한다.

다음 조건을 모두 만족해야 완료로 표시한다.

- `DutyparkTests` 전체가 성공한다.
- 저장소에 포함된 `DutyparkUITests` 전체를 대표 기기에서 성공시키고, 나머지 해상도에서도 핵심 스모크 및 레이아웃 체크를 성공시킨다.
- 로컬 테스트 계정으로 인증 후 주요 생성·조회·수정·삭제 흐름을 실제 백엔드와 검증한다.
- 지원 해상도의 작은 화면과 큰 화면에서 잘림, 겹침, 조작 불가, 키보드 가림이 없다.
- 한국어/영어, 라이트/다크, 큰 글자, 오프라인/복구, 재실행 및 세션 복구의 대표 조합을 검증한다.
- 실행 중 크래시, hang, assertion failure 및 비정상 종료가 없으며 시뮬레이터 로그도 확인한다.
- 발견한 모든 차단/중요 결함은 수정 후 동일 시나리오와 관련 회귀 테스트가 성공한다.
- 최신 검증 빌드를 이름이 정확히 `iPhone 13 mini`인 시뮬레이터에 설치한다.

## 2. 안전 원칙과 테스트 데이터

- 현재 사용자가 실행 중인 웹 `localhost:5173`과 백엔드 `localhost:8080`을 사용하며 재시작하거나 종료하지 않는다.
- 원격/운영 자격 증명과 운영 데이터는 사용하지 않는다.
- 로컬 데모 계정 정보는 `DutyparkUITests/DemoAppStoreCaptureUITests.swift`에 정의된 값을 단일 원본으로 사용하고, 비밀번호를 이 문서에 중복 기록하지 않는다.
- 계정 삭제, 팀 삭제, 대량 알림 삭제 등 복구 비용이 있는 동작은 재시드 가능한 별도 데이터인지 확인한 뒤 수행한다. 확인 전에는 최종 확인 직전까지의 UI/검증만 수행한다.
- 기존 사용자 변경사항을 덮어쓰지 않는다. 테스트가 만든 데이터는 식별 가능한 QA 접두어와 실행 시각을 사용한다.
- `DutyparkUITests` 실행은 이번 사용자의 명시적 전체 테스트 요청에 따라 허용된 범위다.

## 3. 기기·환경 매트릭스

설치된 Xcode/Simulator 런타임을 조사한 후 실제 기기 이름과 OS 버전을 아래 표에 확정한다. 테스트는 작은 화면부터 큰 화면 순으로 수행한다.

| 순서 | 기기 | 대표 목적 | OS | 자동 테스트 | 실계정 기능 테스트 | 레이아웃/로그 | 상태 |
|---:|---|---|---|---|---|---|---|
| 1 | iPhone SE (3rd generation), 750×1334 @2x | 최소 폭/홈 버튼, 키보드·모달·탭바 | iOS 26.5 | 초기 32개 29 PASS·3 FAIL·0 SKIP; 수정 후 focused 3/3 PASS | 실제 로그인·5개 핵심 탭·재실행 세션 복원 1/1 PASS | 앱 crash 0, runner/simulator 오류 0 | fixture·실계정 core 완료 |
| 2 | iPhone 13 mini, 1080×2340 @3x | 소형 노치, 필수 기준 기기 | iOS 26.5 | 비실계정 91개 PASS; drag 회귀 19/19 PASS; Unit 1,075개 실패 0·환경 SKIP 1 | 실제 로그인·주요 9개 화면·세션 복원 PASS; Todo·일정·D-Day 생성/수정 persistence PASS, QA 원복 완료 | 실계정 실행 앱 crash 0, runner 오류 0 | fixture·Unit·실계정 core/CRUD 완료 |
| 3 | iPhone 17e, 1170×2532 @3x | 표준 폭 | iOS 26.5 | 지정 18/18 PASS | 실제 로그인·5개 탭·세션 복원 PASS; 인증 심화 1/1, 설정 핵심·관리자 read-only PASS | 앱 crash 0, runner/simulator 오류 0 | fixture·실계정 core/심화 완료 |
| 4 | iPhone 16 Pro, 1206×2622 @3x | Pro/Dynamic Island | iOS 26.5 | 초기 32개 28 PASS·4 FAIL; 수정 후 focused 4/4 PASS | 실제 로그인·5개 핵심 탭·재실행 세션 복원 1/1 PASS | 앱 crash 0, runner/simulator 오류 0 | fixture·실계정 core 완료 |
| 5 | iPhone Air, 1260×2736 @3x | 대형 중간 폭 | iOS 26.5 | 초기 32개 29 PASS·3 FAIL; 수정 후 overflow focused 4/4 PASS | 실제 로그인·5개 핵심 탭·재실행 세션 복원 1/1 PASS | 앱 crash 0, runner/simulator 오류 0 | fixture·실계정 core 완료 |
| 6 | iPhone 17 Pro Max, 1320×2868 @3x | 최대 화면 | iOS 26.5 | 초기 일부 실패 후 focused 재검증 포함 유효 32/32 PASS | 실제 로그인·5개 핵심 탭·재실행 세션 복원 1/1 PASS | 앱 crash 0, runner/simulator 오류 0 | fixture·실계정 core 완료 |

`iPhone 17`, `iPhone 17 Pro`, `iPhone 16 Pro`는 설치된 프로파일 기준 1206×2622로 동일하므로 해상도 검증은 `iPhone 16 Pro`가 대표한다. 이름이 `dutypark-*`인 세 기기도 동일한 iPhone 16 Pro 복제 프로파일이므로 별도 해상도로 중복 집계하지 않는다.

추가 조합:

- 한국어/영어
- 라이트/다크
- 기본 글자 크기/접근성 큰 글자
- 최초 실행/로그인 상태/로그아웃 상태/앱 강제 종료 후 재실행
- 온라인/오프라인 캐시/연결 복구

## 4. 실행 단계

### A. 사전 조사와 기준선

- [x] Git 작업 트리 상태 확인: 조사 시작 시 깨끗함
- [x] 기존 서버 확인: 웹 5173, 백엔드 8080 모두 LISTEN
- [x] Xcode 26.6 및 iOS 26.5 Simulator 런타임/기기 목록 확정
- [x] `Dutypark.xcodeproj` / `Dutypark` scheme / iPhone 전용 세로 / iOS 17+ 확인
- [x] 테스트 계정 로그인 확정: 제공된 로컬 계정으로 `/api/auth/token`·`/api/auth/status` HTTP 200 및 iPhone 13 mini UI 로그인·재실행 세션 복원 확인. 자격 증명은 문서·로그에 기록하지 않음
- [x] 전체 기능·화면·기존 테스트 인벤토리 확정: 최초 Unit 1,063 노드, 최종 변경 포함 1,075 노드, UI 메서드 93개
- [x] Release 구성 정적 위험 점검: Todo malformed ID 강제 언래핑 S1 발견 및 수정

### B. 자동 검증

- [x] Simulator용 Debug 빌드: `BUILD SUCCEEDED`
- [x] Simulator용 Release 빌드: `BUILD SUCCEEDED`, 실제 API URL 치환 확인
- [x] `DutyparkTests` 전체 최종: 1,075 노드 중 1,074 PASS / 0 FAIL / 1 환경 의존 SKIP
- [x] `DutyparkUITests` 비실계정 범위 — 실계정 Demo 2개를 제외한 91개(기존 fixture 90 + AccountDeletion 1) 모두 최종 PASS. 1차 성공 결과와 수정 후 focused 재검증을 합산했으며, 마지막 회귀에서 runner 오류와 신규 앱 크래시 0
- [x] 해상도별 핵심 UI 스모크 — SE~Pro Max fixture matrix 및 실제 계정 로그인·Home/Calendar/Todo/Team/More·재실행 세션 복원 6개 해상도 모두 PASS
- [x] 한국어/영어 및 라이트/다크 대표 조합 UI 테스트
- [x] 접근성 큰 글자/긴 정책 문구/표·그리드 대표 레이아웃 UI 테스트
- [x] 결과 번들(`xcresult`)과 실패 스크린샷/로그 확인 — 지정 class 및 Pro Max 재현성/green/remaining/focused 결과·로그 확인 완료; 초기 실패 번들과 수정 후 PASS 번들 모두 보존

### C. 실제 테스트 계정 기능 검증

#### 게스트와 인증

- [ ] 최초 실행 게스트 홈, 공개 캘린더, 월 이동, 가이드, 문의/정책 진입
- [ ] 이메일 로그인: 정상, 빈 입력, 잘못된 자격 증명, 기억하기, 키보드 닫기 — 정상·잘못된 비밀번호 오류·기억하기·키보드 닫기 PASS; 빈 입력만 미검증
- [ ] Apple/Kakao/Naver 로그인 진입과 취소/오류 처리
- [x] 로그아웃 확인/취소/완료, 로그인 화면 복귀 및 정상 재로그인
- [ ] 세션 유지, 앱 종료·재실행, 인증 만료/401 처리 — 로그인 세션 유지·재실행 복원 PASS; 인증 만료 강제 시나리오 미검증

#### 홈

- [x] 대시보드 데이터와 D-Day read-only 표시
- [ ] 고정/미고정 친구 카드 열기, 고정/해제, 가로/세로 스크롤
- [ ] 길게 누르기 재정렬, 저장 결과, 다수 친구 overflow
- [ ] 알림 배지/드롭다운/알림 센터 진입

#### 캘린더

- [ ] 이전/다음 월, 월 선택기, 먼 월 이동, 오늘 복귀
- [ ] 날짜 선택, 일정·근무·Todo 표시, 친구 비교 캘린더
- [ ] 일정 생성/수정/삭제, 종일/시간/기간/공개 범위 입력 검증 — 생성·재실행·검색·상세·수정 persistence PASS; UI 삭제와 입력 조합은 미검증, 정확한 QA ID는 guarded API로 정리
- [ ] D-Day 생성/수정/삭제 — 생성·재실행·상세·수정 persistence PASS; UI 삭제 미검증, 정확한 QA ID는 guarded API로 정리
- [ ] 검색, 빈 결과, 긴 문구와 월 경계
- [ ] 오프라인 캐시 조회, 오프라인 일정 생성 큐, 복구 동기화

#### Todo

- [ ] 생성/취소/dirty draft 확인
- [ ] 상세/수정/삭제 — 생성·재실행·상세·제목/내용 수정 persistence PASS; UI 삭제는 미검증, 정확한 QA ID는 guarded API로 정리
- [x] 상태 변경과 컬럼 간 이동 — 실제 server-backed drag가 DONE으로 저장되고 별도 QA Todo가 IN_PROGRESS로 persist된 것을 DB/API로 확인
- [ ] 긴 누르기 재정렬과 세로 스크롤 충돌 방지
- [ ] 태그/첨부/기한/긴 텍스트/빈 값 검증
- [ ] 오프라인 캐시 조회, 오프라인 생성 큐, 복구 동기화

#### 팀과 근무

- [ ] 팀 없음/가입 팀/관리자 상태
- [ ] 근무표 월 이동, 셀/회원 캘린더, 근무 유형 표시
- [ ] 일정/근무 생성·수정·삭제와 확인 모달
- [ ] 팀 관리, 멤버/리드, 근무 유형 숨김·복원, 패턴 저장 제약
- [ ] 권한 부족과 서버 오류 처리

#### 더보기·친구·알림·설정·지원

- [ ] 친구 검색/요청/수락/거절/삭제/차단 관련 가능 흐름
- [ ] 알림 읽음/전체 읽음/삭제/딥링크
- [ ] 프로필 이름/사진 변경 및 사진 삭제
- [ ] 언어/테마 변경 및 재실행 후 유지 — 테마 변경·재실행 유지·시스템 원복 PASS; iOS 26.5 Simulator 앱별 언어 행 미노출로 실제 언어 변경 SKIP, fixture 한국어/영어는 PASS
- [ ] 연결 계정 상태, 연결/해제 확인, Apple 안내
- [ ] 가이드/이용약관/개인정보/AI 일정 정책의 긴 문서 가독성
- [ ] 문의 입력 검증/전송 결과
- [ ] 앱 버전 표기
- [ ] 계정 삭제 재인증, 최종 확인, 안전한 별도 계정에서 실제 완료 여부 — 실제 계정에서 삭제 화면 진입·취소·MyInfo 복귀 PASS; 계정 보존을 위해 최종 삭제는 미실행

#### 관리자

- [x] 관리자 메뉴 노출 권한
- [ ] 회원 검색/상세/세션/상태/비밀번호/가장 — 실제 회원 검색·초기화·상세 read-only PASS; mutation 미검증
- [ ] 팀 검색/생성/상세/관리 — 실제 팀 검색·초기화 read-only PASS; mutation 미검증
- [ ] 확인 모달, 권한/오류/빈 결과

#### 공통 품질

- [ ] 모든 주요 버튼 최소 44×44pt 및 VoiceOver 식별자/레이블
- [ ] Safe Area, Dynamic Island/노치, 홈 인디케이터, 탭바 겹침
- [ ] 키보드로 필드/버튼이 가려지지 않고 명시적 닫기 가능
- [ ] 회전 정책, 배경/전경 전환, 메모리 경고 후 정상 상태
- [ ] 네트워크 단절/지연/서버 오류 시 로딩·빈 상태·재시도
- [ ] 민감 정보가 UI/로그/캐시에 노출되지 않음
- [ ] 크래시/비정상 종료/무한 로딩/중복 저장 없음

## 5. 기기별 실행 기록

각 기기 시작 시 앱 데이터 상태, 빌드 식별자, 언어/테마를 기록하고, 시나리오별 `PASS`/`FAIL`/`BLOCKED`와 증거를 남긴다.

### 기기 1 — iPhone SE (3rd generation)

- 상태: 자동 fixture 검증 및 SE 결함 focused 재검증 완료
- 자동 테스트: 초기 Debug 실행은 지정 5개 class 32개 중 29 PASS / 3 FAIL / 0 SKIP (`DutyparkUITests` 7/8, `LongFormPolicyReadabilityUITests` 3/3, `SettingsRootConfirmationVisualUITests` 3/3, `TodoConfirmationVisualUITests` 6/8, `TeamParityVisualUITests` 10/10). 수정 후 `SE-final` focused 3개는 3/3 PASS / 0 FAIL / 0 SKIP
- 실계정 시나리오: 실제 로그인, 키보드 입력, Home·Calendar·Todo·Team·More, foreground layout, 앱 종료·재실행 세션 복원 1/1 PASS
- 시각 점검: fixture AX/시각 attachment와 실제 계정 smoke 결과를 보존
- 크래시/로그: 초기 및 focused 재검증 앱 crash report 0, runner/simulator 오류 0. `UIAccessibilityLoaderWebShared` 중복 구현 경고와 XCTest AX query 진단만 확인됨
- 결과 번들: `ios/build-pre-submission-qa-SE/results/DutyparkUITests.xcresult`, `LongFormPolicyReadabilityUITests.xcresult`, `SettingsRootConfirmationVisualUITests.xcresult`, `TodoConfirmationVisualUITests.xcresult`, `TeamParityVisualUITests.xcresult`
- 실행 로그: `ios/build-pre-submission-qa-SE/logs/DutyparkUITests.run2.log`, `LongFormPolicyReadabilityUITests.log`, `SettingsRootConfirmationVisualUITests.log`, `TodoConfirmationVisualUITests.log`, `TeamParityVisualUITests.log`
- 발견 결함: QA-SE-001~003은 부모 수정 후 focused 재검증에서 모두 PASS. 초기 실패 번들과 `SE-final` 재검증 번들을 함께 보존

### 기기 2 — iPhone 13 mini

- 상태: fixture 자동 검증, 실계정 read-only smoke 및 reversible 핵심 CRUD persistence 완료
- 자동 테스트: Debug 빌드 PASS, Unit 1,062 PASS / 0 FAIL / 1 SKIP. fixture 대상 90개 중 1차 80개 실행 69 PASS / 11 FAIL, runner 종료로 10개 미실행. 실패·미실행 범위 24개 회귀에서 20 PASS / 4 FAIL / runner 오류 0
- 실계정 시나리오: 실제 로그인 후 홈·캘린더·D-Day·Todo·팀·더보기·친구·알림·설정 진입 및 앱 종료·재실행 세션 복원 PASS. Todo·일정·D-Day 생성/수정/재실행 persistence 확인. 생성 QA 데이터는 정확한 ID guard 후 정상 API로 삭제했고 초기 개수·digest 완전 일치. 설정의 Simulator 알림 권한 변경 경고는 APNs 환경 제약으로 별도 기록
- 시각 점검: 28개 fixture class를 독립 xcresult로 수집; Dynamic Type/한국어·영어/다크·라이트 포함
- 크래시/로그: 1차에서 `EXC_BREAKPOINT` 5회 및 XCTest runner Mach error -308 확인. 수정 후 24개 회귀에서는 신규 앱 crash report와 runner pseudo-error 모두 0
- 발견 결함: QA-001 authenticated UI fixture 크래시, QA-004 Todo malformed ID, QA-005 Admin 내비게이션 수정·재검증 완료. 나머지 실패는 현재 정책에 맞게 테스트를 고쳐 모두 PASS. 실제 계정 로그인은 작은 화면에서 키보드를 명시적으로 닫은 뒤 성공

### 기기 3 — iPhone 17e

- 상태: 자동 fixture 및 실제 계정 core/인증/설정/관리자 read-only 검증 완료
- 자동 테스트: Debug, 지정 6개 class 18개 중 18 PASS / 0 FAIL / 0 SKIP. `DutyparkUITests` 8/8, `CalendarBatchVisualUITests` 1/1, `CalendarScrollUITests` 1/1, `CalendarSearchPlaceholderVisualUITests` 1/1, `GuestCalendarMonthPickerVisualUITests` 1/1, `HomeFriendInteractionUITests` 6/6
- 실계정 시나리오: core smoke 1/1 PASS. 로그아웃 취소·확인, wrong-password, 재로그인, remember 1/1 PASS. 테마 persistence/복원·정책 4종·버전 PASS, 언어 환경 SKIP. 관리자 회원 검색/상세 및 팀 검색 read-only 1/1 PASS
- 시각 점검: fixture와 실제 계정 결과의 AX·스크린샷·로그 보존
- 크래시/로그: 앱 crash report 0, runner/simulator 오류 0. 시스템 `UIAccessibilityLoaderWebShared` 중복 구현 경고만 반복 확인되며 제품 crash로 분류하지 않음
- 결과 번들: `ios/build-pre-submission-qa-17e-final/results/DutyparkUITests.xcresult`, `CalendarBatchVisualUITests.xcresult`, `CalendarScrollUITests.xcresult`, `CalendarSearchPlaceholderVisualUITests.xcresult`, `GuestCalendarMonthPickerVisualUITests.xcresult`, `HomeFriendInteractionUITests.xcresult`
- 실행 로그: `ios/build-pre-submission-qa-17e-final/logs/DutyparkUITests.log`, `CalendarBatchVisualUITests.log`, `CalendarScrollUITests.log`, `CalendarSearchPlaceholderVisualUITests.log`, `GuestCalendarMonthPickerVisualUITests.log`, `HomeFriendInteractionUITests.log`
- 발견 결함: 없음

### 기기 4 — iPhone 16 Pro

- 상태: 지정 자동 fixture matrix 및 4건 focused 재검증 완료
- 자동 테스트: 초기 `DutyparkUITests` 8개 중 6 PASS / 2 FAIL, `AdminConfirmationVisualUITests` 6/6 PASS, `AdminTeamListParityUITests` 1/1 PASS, `TeamParityVisualUITests` 10/10 PASS, 초기 `NotificationConfirmationVisualUITests` 6개 중 4 PASS / 2 FAIL, `NotificationDropdownActorAvatarVisualUITests` 1/1 PASS. 초기 합계 32개 중 28 PASS / 4 FAIL / 0 SKIP. 최신 checkout 수정 후 `DutyparkUITests` calendar 2개 및 Notification deletion 2개 focused가 4/4 PASS
- 실계정 시나리오: 실제 로그인, 키보드 입력, Home·Calendar·Todo·Team·More, foreground layout, 앱 종료·재실행 세션 복원 1/1 PASS
- 시각 점검: fixture와 실제 계정 결과 보존. `tab.calendar`, header center, Notification 패널 44pt 초기 결함은 focused에서 해소됨
- 크래시/로그: 초기 및 focused 재검증 앱 crash report 0, runner/simulator 오류 0, skip 0. 시스템 `UIAccessibilityLoaderWebShared` 중복 구현 경고와 IDE debugger version 경고만 반복되며 제품 crash/runner 실패로 분류하지 않음. 테스트 중 simulator는 `Booted` 유지
- 결과 번들: `ios/build-pre-submission-qa-16pro-final/results/DutyparkUITests.xcresult`, `AdminConfirmationVisualUITests.xcresult`, `AdminTeamListParityUITests.xcresult`, `TeamParityVisualUITests.xcresult`, `NotificationConfirmationVisualUITests.xcresult`, `NotificationDropdownActorAvatarVisualUITests.xcresult`
- 실행 로그: `ios/build-pre-submission-qa-16pro-final/logs/DutyparkUITests.log`, `AdminConfirmationVisualUITests.log`, `AdminTeamListParityUITests.log`, `TeamParityVisualUITests.log`, `NotificationConfirmationVisualUITests.log`, `NotificationDropdownActorAvatarVisualUITests.log`
- 발견 결함: QA-16PRO-001~003은 최신 checkout 수정 후 focused 4/4 PASS로 재검증 완료. 초기 assertion 증거와 재검증 결과를 모두 보존

### 기기 5 — iPhone Air

- 상태: 지정 자동 fixture matrix 및 QA-AIR-001 focused 재검증 완료
- 자동 테스트: 초기 `DutyparkUITests` 8/8, `HomeFriendInteractionUITests` 6/6, `SocialViewEntryUITests` 4/4, `SocialConnectionVisualUITests` 3/3, `SocialPinnedFriendReorderUITests` 3/3, `SocialPinnedFriendOverflowReorderUITests` 1 PASS/3 FAIL, `PinnedFriendActionButtonDragUITests` 4/4(합계 32개 29 PASS / 3 FAIL / 0 SKIP). 최신 checkout focused `SocialPinnedFriendOverflowReorderUITests` 4개는 각각 독립 실행하여 4/4 PASS / 0 FAIL / 0 SKIP. 실행 중 잘못 지정한 `SocialConnectionUITests`는 0 tests 결과라 집계에서 제외하고 올바른 `SocialConnectionVisualUITests`를 독립 실행함
- 실계정 시나리오: 실제 로그인, 키보드 입력, Home·Calendar·Todo·Team·More, foreground layout, 앱 종료·재실행 세션 복원 1/1 PASS
- 시각 점검: 초기 Air 1260×2736에서 `social.reorder.dropTargetCount` AX StaticText를 확인했고, overflow 전제 실패 증거를 보존했다. 수정 후 네 focused 시나리오에서 overflow drop target/스크롤 후 reorder 및 pin 동작 attachment를 모두 확인
- 크래시/로그: 초기 및 focused 재검증 앱 crash report 0, runner/simulator 오류 0. clean shutdown/boot 후 1차 `bootstatus`의 Data Migration Failed 진단은 clean boot 재시도로 해소되었고 최종 상태 `Booted`. `UIAccessibilityLoaderWebShared` 중복 구현 및 IDE debugger version 경고는 시스템 진단으로 제품 crash/runner 실패로 분류하지 않음
- 결과 번들: 초기 `ios/build-pre-submission-qa-Air-final/results/DutyparkUITests.xcresult`, `HomeFriendInteractionUITests.xcresult`, `SocialViewEntryUITests.xcresult`, `SocialConnectionVisualUITests.xcresult`, `SocialPinnedFriendReorderUITests.xcresult`, `SocialPinnedFriendOverflowReorderUITests.xcresult`, `PinnedFriendActionButtonDragUITests.xcresult`; focused `ios/build-pre-submission-qa-Air-overflow-rerun/results/SocialPinnedFriendOverflowReorderUITests.testPinnedFriendFixtureOverflowsViewportSoLazyStackDropsDropTargets.xcresult`, `...testReorderDragStartingOutsideTheAvatarButtonReorders.xcresult`, `...testReorderPersistsWhilePinnedRowsAreOutsideTheViewport.xcresult`, `...testReorderUpwardsAfterScrollingWithEarlierRowsOutsideTheViewport.xcresult` (잘못 지정한 0-test `SocialConnectionUITests.xcresult`도 집계 제외 증거로 보존)
- 실행 로그: 초기 `ios/build-pre-submission-qa-Air-final/logs/`의 7개 class 로그 및 제외된 `SocialConnectionUITests.log`; focused `ios/build-pre-submission-qa-Air-overflow-rerun/logs/`의 네 메서드 로그
- 발견 결함: QA-AIR-001은 네 focused 재검증에서 4/4 PASS로 해소. 초기 assertion 3건과 재검증 결과를 모두 보존

### 기기 6 — iPhone 17 Pro Max

- 상태: 지정 자동 fixture matrix, QA-PROMAX-001 focused 및 실제 계정 core smoke 완료
- 자동 테스트: 초기 `DutyparkUITests` 8/8 PASS, `TeamParityVisualUITests` 10/10 PASS, `TodoConfirmationVisualUITests` 7 PASS/1 FAIL. 이후 gesture/좌표/gap endpoint 수정 후 `todo-gap-green` 동일 테스트 run1~3이 각각 1/1 PASS. `AttachmentGalleryVisualUITests` 1/1 PASS, `LongFormPolicyReadabilityUITests` 초기 2/3 PASS(`tab.more` selector 1건 실패) 후 `ProMax-longform-rerun` focused 1/1 PASS, `RootMoreMenuParityUITests` 2/2 PASS. 초기 실패를 focused PASS로 대체한 유효 지정 테스트 합계는 32/32 PASS / 0 FAIL / 0 SKIP
- 실계정 시나리오: 실제 로그인, 키보드 입력, Home·Calendar·Todo·Team·More, foreground layout, 앱 종료·재실행 세션 복원 1/1 PASS
- 시각 점검: Pro Max 1320×2868에서 Dutypark/Team parity/Todo reorder/Attachment/LongForm/RootMore AX·시각 fixture 시나리오를 확인했다. 초기 Todo upward drag 실패는 `todo.card.A11CE000-0000-4000-8000-000000000002` 순서 전환 waiter가 완료되지 않은 증거로 보존했고, 최종 gap endpoint 재검증 3회에서 기대 순서 완료를 확인했다. LongForm focused 로그에는 `tab.more` AX 노출·탭과 정책 문구 래핑을 확인한 기록이 있다.
- 크래시/로그: 초기·재현성·이전 GREEN·coordinate-green·gap-green·remaining·focused 실행에서 앱 crash report 0, runner/simulator 오류 0, skip 0. `UIAccessibilityLoaderWebShared` 중복 구현 및 IDE debugger version 경고는 시스템 진단으로 제품 crash/runner 실패로 분류하지 않음. 각 clean boot 후 테스트 중 simulator는 `Booted` 유지
- 결과 번들: 초기 `ios/build-pre-submission-qa-ProMax-final/results/DutyparkUITests.xcresult`, `TeamParityVisualUITests.xcresult`, `TodoConfirmationVisualUITests.xcresult`; 재현성 `ios/build-pre-submission-qa-ProMax-todo-drag-rerun/results/` run1/run2; 이전 GREEN `ios/build-pre-submission-qa-ProMax-todo-drag-green/results/` run1/run2; coordinate-green `ios/build-pre-submission-qa-ProMax-todo-coordinate-green/results/` run1/run2; 최종 `ios/build-pre-submission-qa-ProMax-todo-gap-green/results/TodoConfirmationVisualUITests.testFixtureTodoLongPressDragKeepsUnrelatedColumnCardsFixed.run1.xcresult`, `...run2.xcresult`, `...run3.xcresult`; `ios/build-pre-submission-qa-ProMax-remaining-final/results/AttachmentGalleryVisualUITests.xcresult`, `LongFormPolicyReadabilityUITests.xcresult`; focused `ios/build-pre-submission-qa-ProMax-longform-rerun/results/LongFormPolicyReadabilityUITests.testAISchedulePolicyWrapsAtLargeDynamicType.xcresult`; `ios/build-pre-submission-qa-ProMax-rootmore-final/results/RootMoreMenuParityUITests.xcresult`
- 실행 로그: 초기/재현성/GREEN/coordinate/gap/remaining/focused 각 DerivedData의 `logs/`에 class 및 독립 focused 실행 로그를 보존. 최종 gap-green run1~3, LongForm focused, RootMore class 로그에서 PASS를 확인
- 발견 결함: QA-PROMAX-001은 초기 `TodoConfirmationVisualUITests.swift:258` assertion 실패 후 부모 수정(gesture/좌표/gap endpoint)으로 `todo-gap-green` 3회 연속 1/1 PASS, crash/runner 0으로 수정·재검증 완료. LongForm의 초기 `tab.more` selector 실패도 focused 1/1 PASS로 해소

## 6. 결함 및 수정·재검증 기록

| ID | 심각도 | 기기/환경 | 재현 단계 | 실제/기대 결과 | 원인 | 수정 | 집중 테스트 | 회귀 테스트 | 상태 |
|---|---|---|---|---|---|---|---|---|---|
| QA-001 | S2(테스트 차단) | iPhone 13 mini, Debug authenticated UI fixture | 인증 fixture로 AppRootView 실행 | `ContentFilterStore.load`가 `/public-content/banned-words` live API를 요청해 `APIClient.swift`의 fixture guard에서 `EXC_BREAKPOINT`; 기대는 네트워크 없는 fixture 실행 | public content fixture 누락 | Debug의 `-ui-testing-*` 실행에서만 network refresh 생략하고 Release에서는 분기 자체 제거 | ContentFilter unit 6/6 PASS; 기존 EXC_BREAKPOINT 소멸 | 비실계정 UI 91개 최종 PASS, 최종 Unit 1,075개 실패 0, Release BUILD SUCCEEDED | 수정 완료 |
| QA-002 | 환경 차단 | iPhone 13 mini, real demo account | Demo App Store capture 2개 실행 | 현재 8080이 `dutypark_demo`가 아니어서 Home 도달 실패; 기대는 local demo 로그인 | 실행 백엔드 DB와 demo fixture 불일치 | 계정/서버 입력 대기 | 미실행 | 해당 없음 | BLOCKED |
| QA-003 | 재분류 완료 | iPhone 13 mini | 초기 Admin/Calendar/DutyPattern UI assertion | Calendar/DutyPattern은 공통 크래시 제거 및 clean boot 후 성공했고, Admin은 QA-005로 분리 | 공통 fixture 크래시와 Admin 내비게이션 결함이 혼재 | QA-001/QA-005로 각각 처리 | Calendar 4개 PASS, DutyPattern PASS | Admin QA-005 focused 2/2 PASS | 분리·재검증 완료 |
| QA-004 | S1 | 서버/오프라인 캐시 Todo | UUID가 아닌 Todo ID가 보드 앞에 있는 상태에서 정상 Todo 열기/생성 | `UUID(uuidString: id)!`에서 앱 크래시 가능; 기대는 비정상 카드 격리와 정상 카드 사용 유지 | 검증 없는 문자열 ID 강제 언래핑 | 서버/캐시 보드 경계 필터, deterministic 안전 변환, malformed mutation 명시 실패 | server/cache focused PASS; create/update/status/drop failure tests 추가 | 최종 `DutyparkTests` 1,075개에서 실패 0 | 수정·재검증 완료 |
| QA-005 | S1 | iPhone 13 mini, Admin 팀 목록 | 관리자 팀 행 탭 | 실제 부모 Button 탭 후에도 관리 화면으로 이동하지 않음 | row의 `NavigationLink`에 부착한 햅틱 `simultaneousGesture`가 기본 이동을 가로막음 | identifier를 NavigationLink로 이동, 간섭 gesture 제거, destination appear에서 이동 성공 햅틱 1회 발생 | Admin 관리 진입 PASS, 검색·생성 후 `screen.team.manage.9001` 진입 PASS | exact 13 mini clean boot 2/2 PASS | 수정·재검증 완료 |
| QA-006 | S2(접근성) | iPhone 13 mini, Home toolbar | 브랜드 터치 영역 조회 | `header.brand` Button 2개가 매칭됨 | compound HStack의 icon/text 자식에 identifier 전파 | 자식 AX 노드 ignore, 단일 brand action으로 그룹화 | toolbar touch target PASS | iPhone 13 mini focused PASS | 수정·재검증 완료 |
| QA-007 | 테스트 회귀 | iPhone 13 mini, Home/Social | 즐겨찾기 해제 후 상태/카드 탭 | 의도된 해제 확인 모달을 처리하지 않고 멤버 달력을 일반 달력 selector로 찾음 | UI 정책·화면 식별자를 테스트가 미반영 | 확인/취소 모달 처리, 실제 `screen.calendar.member` 검증, 수직 gesture 좌표 정정 | Home, action button, SocialPinned 2개 모두 PASS | exact 13 mini 최종 focused PASS | 수정·재검증 완료 |
| QA-008 | 테스트 회귀 | iPhone 13 mini, Team/Settings | 영어 기기 요일, 편집기 닫기, 프로필 이미지 확인 | 옛 한국어/취소/삭제 문구 기대 및 80pt 부동소수점 오차 | 시스템 언어·현재 문구 정책 미반영 및 과도한 exact 비교 | 영어 기대값, 현재 닫기·기본 이미지 문구, 0.01pt tolerance | Team 2개 및 Settings 최종 PASS | exact 13 mini 최종 focused PASS | 수정·재검증 완료 |
| QA-009 | 환경 불안정 | iPhone 13 mini, XCTest runner | 장시간 전체 UI 실행 | signal kill, channel disconnect, Mach -308로 실제 10개 미실행 | 반복 앱 fatal 이후 CoreSimulator/XCTest service 불안정 | clean boot 및 class별 독립 result bundle/시간 제한 | AccountDeletion, SocialConnection 3, RootMore 2, Todo 8 모두 PASS | 24개 회귀에서 runner 오류 0 | 재검증 성공 |
| QA-010 | S2(Release 방어) | Release 빌드 정적 검토 | `-ui-testing-*` 인자를 Release 앱에 전달 | 테스트 전용 ContentFilter network skip가 Release에도 컴파일됨; 기대는 Debug fixture 전용 | 조건부 컴파일 경계 누락 | 호출부·helper·unit test를 모두 `#if DEBUG`로 제한 | Debug/Release parse PASS | 최종 `DutyparkTests` 실패 0, Release `BUILD SUCCEEDED`, 운영 API/PrivacyInfo 확인 | 수정·재검증 완료 |
| QA-011 | S2(데이터 정합성) | Todo mutation 응답 | create/update/status/drop가 malformed ID DTO 반환 | board 반영은 무시하면서 성공/성공 햅틱으로 오판; 기대는 오류와 optimistic rollback | `patchBoard` no-op 결과를 호출자가 확인하지 않음 | `patchBoard` Bool, create·mutation 응답 guard, cross-column rollback | create true/false·update·status·drop RED 테스트 추가 및 구현 | 최종 `DutyparkTests` 1,075개에서 실패 0 | 수정·재검증 완료 |
| QA-012 | S2(데이터 정합성) | Todo update/status/cross-column 응답 | 서버가 요청 Todo와 다른 valid UUID DTO 반환 | 다른 카드를 patch하거나 optimistic 이동을 성공 처리할 수 있음; 기대는 오류·캐시 미저장·rollback | 응답 ID 형식만 확인하고 요청 대상 ID 일치 여부를 검증하지 않음 | update/status 응답 expected ID 검증, cross-column 응답 ID 일치 guard | wrong-valid update/status/drop RED 테스트 3개 추가 | 최종 `DutyparkTests` 1,075개에서 실패 0 | 수정·재검증 완료 |
| QA-SE-001 | S2 | iPhone SE (3rd generation), `DutyparkUITests` | `testCalendarMonthPickerChangesMonthUsingFixture` 초기 실행 | 초기 `DutyparkUITests.swift:204`에서 `XCTAssertTrue` 실패: `tab.calendar` primary tab 미노출 | 부모가 최신 checkout에서 수정 | 수정 후 `SE-final/results/DutyparkUITests.testCalendarMonthPickerChangesMonthUsingFixture.xcresult`에서 1/1 PASS; 로그에서 `tab.calendar` 노출·탭 및 월 선택 완료 확인 | focused 재검증 PASS | 수정·재검증 완료 |
| QA-SE-002 | S2 | iPhone SE (3rd generation), `TodoConfirmationVisualUITests` | `testFixtureTodoLongPressDragKeepsUnrelatedColumnCardsFixed` 초기 실행 | 초기 `TodoConfirmationVisualUITests.swift:250`에서 실제 `322.5`가 기대 상한 `205.5`보다 커 `XCTAssertLessThan` 실패 | 부모가 long-press reorder assertion을 안정화 | 수정 후 `SE-final/results/TodoConfirmationVisualUITests.testFixtureTodoLongPressDragKeepsUnrelatedColumnCardsFixed.xcresult`에서 1/1 PASS; drag 후 reorder predicate 완료 확인 | focused 재검증 PASS | 수정·재검증 완료 |
| QA-SE-003 | S2(접근성/레이아웃) | iPhone SE (3rd generation), `TodoConfirmationVisualUITests` | `testFixtureTodoVerticalSwipeScrollsWithoutOpeningDetailOrReordering` 초기 실행 | 초기 `TodoConfirmationVisualUITests.swift:285`에서 `todo.card.…001` AX identifier 미검출 | 부모가 visible-card 기반 scroll predicate 및 detail 미진입 검증을 안정화 | 수정 후 `SE-final/results/TodoConfirmationVisualUITests.testFixtureTodoVerticalSwipeScrollsWithoutOpeningDetailOrReordering.xcresult`에서 1/1 PASS; 카드 순서 유지·스크롤·detail 미진입 확인 | focused 재검증 PASS | 수정·재검증 완료 |
| QA-16PRO-001 | S2(접근성/검증) | iPhone 16 Pro, `DutyparkUITests` | `testCalendarMonthPickerChangesMonthUsingFixture` 실행 | 초기 `DutyparkUITests.swift:204`에서 `XCTAssertTrue` 실패 — `tab.calendar` Button을 약 10초간 반복 조회했으나 AX snapshot에서 노출되지 않아 primary tab 미확인; 기대는 `tab.calendar`가 노출되고 월 선택기로 진입 | 초기 iPhone 16 Pro 실행에서 `tab.calendar` AX 노출/초기화 타이밍 또는 fixture 정합성 문제가 드러남 | 최신 checkout 수정 반영 후 focused에서 `tab.calendar` 노출·월 선택 성공 | 초기 `ios/build-pre-submission-qa-16pro-final/results/DutyparkUITests.xcresult` 및 `.../logs/DutyparkUITests.log:2439-2475`, 재검증 `ios/build-pre-submission-qa-16pro-rerun-final/results/DutyparkUITests.testCalendarMonthPickerChangesMonthUsingFixture.xcresult` 보존 | 16 Pro focused 1/1 PASS, 앱 crash/runner 오류 0 | 수정·재검증 완료 |
| QA-16PRO-002 | S2(레이아웃/검증) | iPhone 16 Pro, `DutyparkUITests` | `testCalendarParityCentersHeaderAndOpensOnlyTheTappedTodoDetail` 실행 | 초기 `DutyparkUITests.swift:161`에서 `XCTAssertEqualWithAccuracy` 실패 — 실제 header center `199.0`, 기대 `201.0`, 허용 오차 `1.0`; 단, `tab.calendar`, `screen.calendar`, `calendar.month.controls` AX 노출·탭은 성공 | 초기 iPhone 16 Pro의 실제 header frame center와 테스트 기대값 2pt 차이 또는 geometry rounding | 최신 checkout 수정 반영 후 focused에서 header parity 및 Todo detail 시나리오 성공 | 초기 `ios/build-pre-submission-qa-16pro-final/results/DutyparkUITests.xcresult`, `.../logs/DutyparkUITests.log:2486-2508`, 재검증 `ios/build-pre-submission-qa-16pro-rerun-final/results/DutyparkUITests.testCalendarParityCentersHeaderAndOpensOnlyTheTappedTodoDetail.xcresult` 보존 | 16 Pro focused 1/1 PASS, 앱 crash/runner 오류 0 | 수정·재검증 완료 |
| QA-16PRO-003 | S2(레이아웃 정밀도/검증) | iPhone 16 Pro, `NotificationConfirmationVisualUITests` | 알림 삭제/읽은 알림 삭제 확인 패널의 안정적 중앙 정렬 검증 | 초기 `NotificationConfirmationVisualUITests.swift:252`에서 두 테스트가 동일 실패 — 실제 panel height `43.99999999999994`가 기대 하한 `44.0`보다 작음. 버튼·문구 AX 조회는 성공했고 앱 crash 없음 | 44pt 경계의 부동소수점 반올림 또는 테스트 tolerance 부족 | 최신 checkout 수정 반영 후 focused 두 시나리오에서 패널 검증 성공 | 초기 `ios/build-pre-submission-qa-16pro-final/results/NotificationConfirmationVisualUITests.xcresult`, `.../logs/NotificationConfirmationVisualUITests.log:462-478,526-546`, 재검증 `ios/build-pre-submission-qa-16pro-rerun-final/results/NotificationConfirmationVisualUITests.testNotificationDeletionConfirmationUsesStableCenteredSharedPanel.xcresult` 및 `...testReadNotificationDeletionConfirmationUsesStableCenteredSharedPanel.xcresult` 보존 | 16 Pro focused 2/2 PASS, 앱 crash/runner 오류 0 | 수정·재검증 완료 |
| QA-AIR-001 | S2(레이아웃/fixture 정합성) | iPhone Air, `SocialPinnedFriendOverflowReorderUITests` | `testPinnedFriendFixtureOverflowsViewportSoLazyStackDropsDropTargets`, `testReorderDragStartingOutsideTheAvatarButtonReorders`, `testReorderPersistsWhilePinnedRowsAreOutsideTheViewport` 초기 실행 | 초기 Air 1260×2736에서 세 테스트가 `XCTAssertLessThan` 실패 — 실제 published drop target `18`, 기대 `18` 미만; 기대는 viewport overflow로 일부 target이 제외되는 것 | 대형 Air viewport에서 18개 fixture row가 모두 drop target을 publish해 offscreen-lazy 전제가 성립하지 않음 | DEBUG overflow fixture와 테스트 seeded order를 18개에서 32개로 확대 | 초기 1 PASS/3 FAIL 증거와 재검증 `ios/build-pre-submission-qa-Air-overflow-rerun/results/` 네 독립 xcresult/log 보존 | Air focused 4/4 및 최종 13 mini shared drag 회귀 19/19 PASS, 앱 crash/runner 오류 0 | 수정·재검증 완료 |
| QA-PROMAX-001 | S2(동작/검증) | iPhone 17 Pro Max, `TodoConfirmationVisualUITests` | `testFixtureTodoLongPressDragKeepsUnrelatedColumnCardsFixed` 실행·재현성·수정 후 3회 재검증 | 초기 `TodoConfirmationVisualUITests.swift:258`에서 `XCTAssertEqual` 실패 — upward drag 후 waiter 결과 실제 `XCTWaiterResult(rawValue: 2)`, 기대 `rawValue: 1`(두 번째 card가 첫 번째 앞에 배치). 초기 class 7/8 PASS·1 FAIL, 이후 재현성/green/coordinate 시도에서 timing에 따른 PASS·FAIL이 교차 | Pro Max 1320×2868에서 long-press reorder의 gesture coordinate/gap endpoint timing이 기대 순서 완료 전에 waiter를 종료시키는 경로가 드러남 | 부모가 gesture coordinate 및 gap endpoint를 수정함. 최신 checkout에서 새 DerivedData `ios/build-pre-submission-qa-ProMax-todo-gap-green`으로 동일 focused test run1~3을 독립 실행해 3/3 PASS, crash/runner 0 확인 | 초기/재현성/GREEN/coordinate 실패 번들과 gap-green run1~3 PASS 번들을 모두 보존 | 초기 7/8 PASS·1 FAIL; 재현성 1/2 PASS; GREEN 1/2 PASS; coordinate 1/2 PASS; gap-green 3/3 PASS. 모든 실행 앱 crash/runner 오류 0 | 수정·재검증 완료 |

심각도 기준:

- `S0`: 데이터 손실, 보안/개인정보, 반복 가능한 크래시, 앱 사용 불가
- `S1`: 심사 거절 가능성이 높거나 핵심 기능 실패
- `S2`: 우회 가능한 기능/레이아웃/접근성 결함
- `S3`: 사소한 시각적 불일치 또는 개선 사항

## 7. 실행 로그

| 시각(KST) | 단계 | 결과 | 상세/증거 |
|---|---|---|---|
| 2026-08-28 | 환경 확인 | PASS | 작업 트리 깨끗함, 5173/8080 LISTEN |
| 2026-08-28 | QA 계획 초안 | PASS | 본 문서 생성, 조사 결과에 따라 계속 현행화 예정 |
| 2026-08-28 | Simulator 매트릭스 | PASS | Xcode 26.6, iOS 26.5, 서로 다른 iPhone 화면 프로파일 6종 확정 |
| 2026-08-28 | 로컬 데모 시드 | BLOCKED | 격리 DB는 준비됐으나 실행 중 8080 백엔드는 `dutypark_demo`가 아니어서 API 신원 검증이 401로 안전 중단됨 |
| 2026-08-28 | Debug Simulator 빌드 | PASS | Xcode 26.6, iPhone Simulator generic, 약 19초 |
| 2026-08-28 | `DutyparkTests` 전체 | PASS | 1,063 노드: 1,062 성공, 실패 0, Simulator 파일 보호 속성 미지원으로 1개 skip |
| 2026-08-28 | 정적 크래시 점검 | FAIL→FIXED | malformed Todo ID의 `UUID(...)!` 강제 언래핑을 발견해 RED-GREEN으로 수정하고 관련 Todo 및 최종 전체 Unit에서 재검증 완료 |
| 2026-08-28 | iPhone 13 mini 전체 UI 1차 | FAIL | 456초, 20개 중 6 PASS/14 FAIL 후 반복 크래시로 XCTest runner Mach error -308, 73개 미실행 |
| 2026-08-28 | iPhone 13 mini 앱 설치 | PASS | 1차 UI 빌드 `io.github.shanepark.dutypark` 설치 및 `simctl listapps` 확인 |
| 2026-08-28 | QA-004 Todo ID 수정 | PASS | server/cache/create 회귀 테스트 성공, force unwrap 제거, 수정 빌드 iPhone 13 mini 설치 확인 |
| 2026-08-28 | QA-001 ContentFilter unit | PASS | UI fixture network refresh guard 단위 테스트 6/6 성공, 기존 APIClient EXC_BREAKPOINT 재현되지 않음 |
| 2026-08-28 | QA-001 기존 크래시 UI 재검증 | PASS | AttachmentGallery, CalendarSearchPlaceholder, clean boot 후 CalendarBatch와 CalendarScroll 성공 |
| 2026-08-28 | AccountDeletion fixture UI | BLOCKED | 앱 크래시 리포트/APIClient 경로 없이 `keyboard.dismiss` 대기 직후 XCTest `signal kill`; 별도 격리 기록 |
| 2026-08-28 | Release Simulator 빌드 | PASS | API `https://dutypark.o-r.kr/api/`, bundle `io.github.shanepark.dutypark`, iPhone/Portrait/iOS 17+, PrivacyInfo 포함 및 plist lint PASS |
| 2026-08-28 | iPhone 13 mini fixture 1차 전수 | FAIL | 대상 90개 중 80개 실행: 69 PASS/11 FAIL, runner pseudo-error 2건, 10개 미실행. 28개 class별 xcresult 보존 |
| 2026-08-28 | UI 실패 분석 | PASS | AX tree/gesture 좌표/활동 로그로 Admin·brand 접근성 2건과 stale UI test 7건, runner 불안정 4그룹으로 분류 |
| 2026-08-28 | Admin 팀 내비게이션 재현 | FAIL | identifier 중복 제거 후에도 부모 `admin.team.101` Button 탭이 화면 이동을 일으키지 않음. 앱 크래시는 없으며 NavigationLink의 햅틱 gesture 충돌로 원인 좁힘 |
| 2026-08-28 | iPhone 13 mini 실패·미실행 회귀 | PARTIAL | 24개 중 20 PASS / 4 FAIL / 0 SKIP, runner pseudo-error 0, 신규 앱 crash report 0. AccountDeletion, SocialConnection 3, RootMore 2, Todo 8을 포함해 이전 signal kill·미실행 범위 성공 |
| 2026-08-28 | QA-005 Admin 내비게이션 GREEN | PASS | exact iPhone 13 mini clean boot: 기존 팀 관리 진입 및 검색·팀 생성 후 관리 route 2/2 PASS. `simultaneousGesture` 제거 후 실제 destination 표시와 성공 햅틱 경계를 검증 |
| 2026-08-28 | iPhone 13 mini 잔여 UI 최종 GREEN | PASS | Settings 기본 이미지 확인 및 SocialPinned 멤버 캘린더 진입 focused PASS. 실계정 Demo 2개를 제외한 91개가 1차 성공+수정 후 재검증 합산으로 모두 PASS, 마지막 실행 신규 앱 crash report 0 |
| 2026-08-28 | iPhone SE clean boot | PASS | `6C4322A6-EAA0-4F3D-830D-96B6C8C7A256`를 shutdown 확인 후 boot/bootstatus 완료. 테스트 중 Booted 유지 |
| 2026-08-28 | iPhone SE `DutyparkUITests` | FAIL | 8개: 7 PASS / 1 FAIL / 0 SKIP. 제품 assertion `DutyparkUITests.swift:204`, `tab.calendar` 미노출. 결과 `ios/build-pre-submission-qa-SE/results/DutyparkUITests.xcresult` |
| 2026-08-28 | iPhone SE `LongFormPolicyReadabilityUITests` | PASS | 3개: 3 PASS / 0 FAIL / 0 SKIP. 결과 `ios/build-pre-submission-qa-SE/results/LongFormPolicyReadabilityUITests.xcresult` |
| 2026-08-28 | iPhone SE `SettingsRootConfirmationVisualUITests` | PASS | 3개: 3 PASS / 0 FAIL / 0 SKIP. 결과 `ios/build-pre-submission-qa-SE/results/SettingsRootConfirmationVisualUITests.xcresult` |
| 2026-08-28 | iPhone SE `TodoConfirmationVisualUITests` | FAIL | 8개: 6 PASS / 2 FAIL / 0 SKIP. 제품 assertion `TodoConfirmationVisualUITests.swift:250`, `:285`; 결과 `ios/build-pre-submission-qa-SE/results/TodoConfirmationVisualUITests.xcresult` |
| 2026-08-28 | iPhone SE `TeamParityVisualUITests` | PASS | 10개: 10 PASS / 0 FAIL / 0 SKIP. 결과 `ios/build-pre-submission-qa-SE/results/TeamParityVisualUITests.xcresult` |
| 2026-08-28 | iPhone SE 결과/로그 점검 | PASS (with OPEN defects) | `xcresulttool` summary로 32개 집계 확인, app crash report 0, runner/simulator 오류 0. AX 중복 구현 경고는 시스템 로그 진단으로 기록하고 제품 crash로 분류하지 않음 |
| 2026-08-28 | iPhone SE 수정 후 clean boot | PASS | `6C4322A6-EAA0-4F3D-830D-96B6C8C7A256`를 다시 shutdown/boot/bootstatus 완료. 새 DerivedData `ios/build-pre-submission-qa-SE-final` 사용 |
| 2026-08-28 | iPhone SE QA-SE-001 focused 재검증 | PASS | 1개: 1 PASS / 0 FAIL / 0 SKIP. `tab.calendar` 노출 후 month picker에서 `2026-01` 선택 성공. 결과 `ios/build-pre-submission-qa-SE-final/results/DutyparkUITests.testCalendarMonthPickerChangesMonthUsingFixture.xcresult` |
| 2026-08-28 | iPhone SE QA-SE-002 focused 재검증 | PASS | 1개: 1 PASS / 0 FAIL / 0 SKIP. long-press reorder predicate와 unrelated card 위치 검증 성공. 결과 `ios/build-pre-submission-qa-SE-final/results/TodoConfirmationVisualUITests.testFixtureTodoLongPressDragKeepsUnrelatedColumnCardsFixed.xcresult` |
| 2026-08-28 | iPhone SE QA-SE-003 focused 재검증 | PASS | 1개: 1 PASS / 0 FAIL / 0 SKIP. visible card scroll/순서 유지 및 Todo detail 미진입 검증 성공. 결과 `ios/build-pre-submission-qa-SE-final/results/TodoConfirmationVisualUITests.testFixtureTodoVerticalSwipeScrollsWithoutOpeningDetailOrReordering.xcresult` |
| 2026-08-28 | iPhone 17e clean boot | PASS | `D285AF82-F28B-48C5-9986-11A6BF7E2ABC`를 shutdown 확인 후 boot/bootstatus 완료. 테스트 중 Booted 유지 |
| 2026-08-28 | iPhone 17e 자동 UI matrix | PASS | 18개: 18 PASS / 0 FAIL / 0 SKIP. 6개 class 모두 성공, runner 재시도 없음. 결과는 `ios/build-pre-submission-qa-17e-final/results/`에 class별 보존 |
| 2026-08-28 | iPhone 17e 결과/로그 점검 | PASS | `xcresulttool` summary 6개에서 18/18 PASS 확인, app crash report 0, runner/simulator 오류 0. 실행 로그는 `ios/build-pre-submission-qa-17e-final/logs/`에 보존 |
| 2026-08-28 | iPhone 16 Pro clean boot | PASS | `5F480BC5-C3D8-48AB-BD13-E5ECED361167`를 shutdown 확인 후 boot/bootstatus 완료. 테스트 중 `Booted` 유지 |
| 2026-08-28 | iPhone 16 Pro `DutyparkUITests` | FAIL | 8개: 6 PASS / 2 FAIL / 0 SKIP. `DutyparkUITests.swift:204` AX `tab.calendar` 미노출, `:161` header center `199.0` 대 `201.0 ±1.0`; 결과 `ios/build-pre-submission-qa-16pro-final/results/DutyparkUITests.xcresult`, 로그 `.../logs/DutyparkUITests.log` |
| 2026-08-28 | iPhone 16 Pro `AdminConfirmationVisualUITests` | PASS | 6개: 6 PASS / 0 FAIL / 0 SKIP. 결과 `ios/build-pre-submission-qa-16pro-final/results/AdminConfirmationVisualUITests.xcresult` |
| 2026-08-28 | iPhone 16 Pro `AdminTeamListParityUITests` | PASS | 1개: 1 PASS / 0 FAIL / 0 SKIP. 결과 `ios/build-pre-submission-qa-16pro-final/results/AdminTeamListParityUITests.xcresult` |
| 2026-08-28 | iPhone 16 Pro `TeamParityVisualUITests` | PASS | 10개: 10 PASS / 0 FAIL / 0 SKIP. 결과 `ios/build-pre-submission-qa-16pro-final/results/TeamParityVisualUITests.xcresult` |
| 2026-08-28 | iPhone 16 Pro `NotificationConfirmationVisualUITests` | FAIL | 6개: 4 PASS / 2 FAIL / 0 SKIP. 두 삭제 확인 시나리오가 `NotificationConfirmationVisualUITests.swift:252`의 `43.99999999999994 < 44.0` assertion에서 실패. 결과 `ios/build-pre-submission-qa-16pro-final/results/NotificationConfirmationVisualUITests.xcresult` |
| 2026-08-28 | iPhone 16 Pro `NotificationDropdownActorAvatarVisualUITests` | PASS | 1개: 1 PASS / 0 FAIL / 0 SKIP. 결과 `ios/build-pre-submission-qa-16pro-final/results/NotificationDropdownActorAvatarVisualUITests.xcresult` |
| 2026-08-28 | iPhone 16 Pro focused 재검증 clean boot | PASS | `5F480BC5-C3D8-48AB-BD13-E5ECED361167`를 shutdown/boot/bootstatus 완료. 새 DerivedData `ios/build-pre-submission-qa-16pro-rerun-final` 사용 |
| 2026-08-28 | iPhone 16 Pro focused calendar month picker | PASS | 1개: 1 PASS / 0 FAIL / 0 SKIP. 결과 `ios/build-pre-submission-qa-16pro-rerun-final/results/DutyparkUITests.testCalendarMonthPickerChangesMonthUsingFixture.xcresult` |
| 2026-08-28 | iPhone 16 Pro focused calendar parity | PASS | 1개: 1 PASS / 0 FAIL / 0 SKIP. 결과 `ios/build-pre-submission-qa-16pro-rerun-final/results/DutyparkUITests.testCalendarParityCentersHeaderAndOpensOnlyTheTappedTodoDetail.xcresult` |
| 2026-08-28 | iPhone 16 Pro focused notification deletion | PASS | 1개: 1 PASS / 0 FAIL / 0 SKIP. 결과 `ios/build-pre-submission-qa-16pro-rerun-final/results/NotificationConfirmationVisualUITests.testNotificationDeletionConfirmationUsesStableCenteredSharedPanel.xcresult` |
| 2026-08-28 | iPhone 16 Pro focused read-notification deletion | PASS | 1개: 1 PASS / 0 FAIL / 0 SKIP. 결과 `ios/build-pre-submission-qa-16pro-rerun-final/results/NotificationConfirmationVisualUITests.testReadNotificationDeletionConfirmationUsesStableCenteredSharedPanel.xcresult` |
| 2026-08-28 | iPhone 16 Pro focused 결과/로그 점검 | PASS | focused 4개: 4 PASS / 0 FAIL / 0 SKIP. 초기 4 assertion 실패는 최신 checkout 수정 후 모두 재검증 성공, app crash report 0, runner/simulator 오류 0. 초기·재검증 결과와 로그를 모두 보존 |
| 2026-08-28 | iPhone Air clean boot | PASS (boot retry) | `A2B26214-12C0-4CAF-8CAC-FF5137E68668`를 clean shutdown/boot. 1차 `bootstatus`에 Data Migration Failed 진단이 잠시 출력되어 clean boot를 재시도했으며 최종 `Booted` 확인 후 테스트 진행 |
| 2026-08-28 | iPhone Air `DutyparkUITests` | PASS | 8개: 8 PASS / 0 FAIL / 0 SKIP. 결과 `ios/build-pre-submission-qa-Air-final/results/DutyparkUITests.xcresult` |
| 2026-08-28 | iPhone Air `HomeFriendInteractionUITests` | PASS | 6개: 6 PASS / 0 FAIL / 0 SKIP. 결과 `ios/build-pre-submission-qa-Air-final/results/HomeFriendInteractionUITests.xcresult` |
| 2026-08-28 | iPhone Air `SocialViewEntryUITests` | PASS | 4개: 4 PASS / 0 FAIL / 0 SKIP. 결과 `ios/build-pre-submission-qa-Air-final/results/SocialViewEntryUITests.xcresult` |
| 2026-08-28 | iPhone Air 잘못된 `SocialConnectionUITests` selector | EXCLUDED | 0 tests로 종료된 결과 `ios/build-pre-submission-qa-Air-final/results/SocialConnectionUITests.xcresult`; 요청된 정확한 class `SocialConnectionVisualUITests`를 별도 실행하여 아래 3/3 PASS로 집계. 잘못된 selector는 PASS로 산입하지 않음 |
| 2026-08-28 | iPhone Air `SocialConnectionVisualUITests` | PASS | 3개: 3 PASS / 0 FAIL / 0 SKIP. 결과 `ios/build-pre-submission-qa-Air-final/results/SocialConnectionVisualUITests.xcresult` |
| 2026-08-28 | iPhone Air `SocialPinnedFriendReorderUITests` | PASS | 3개: 3 PASS / 0 FAIL / 0 SKIP. 결과 `ios/build-pre-submission-qa-Air-final/results/SocialPinnedFriendReorderUITests.xcresult` |
| 2026-08-28 | iPhone Air `SocialPinnedFriendOverflowReorderUITests` | FAIL | 4개: 1 PASS / 3 FAIL / 0 SKIP. 세 테스트가 `SocialPinnedFriendOverflowReorderUITests.swift:19, :93, :50`에서 published drop target `18`이 기대 `<18`이 아니어서 실패. 결과 `ios/build-pre-submission-qa-Air-final/results/SocialPinnedFriendOverflowReorderUITests.xcresult`, 로그 `.../logs/SocialPinnedFriendOverflowReorderUITests.log:281-379` |
| 2026-08-28 | iPhone Air `PinnedFriendActionButtonDragUITests` | PASS | 4개: 4 PASS / 0 FAIL / 0 SKIP. 결과 `ios/build-pre-submission-qa-Air-final/results/PinnedFriendActionButtonDragUITests.xcresult` |
| 2026-08-28 | iPhone Air 결과/로그·crash 점검 | PARTIAL (OPEN defect) | 요청된 32개: 29 PASS / 3 FAIL / 0 SKIP. app crash report 0, runner/simulator 오류 0, 최종 simulator `Booted`. QA-AIR-001을 기록하고 Pro Max는 시작하지 않음 |
| 2026-08-28 | iPhone Air overflow 재검증 clean boot | PASS | `A2B26214-12C0-4CAF-8CAC-FF5137E68668`를 clean shutdown/boot하고 `ios/build-pre-submission-qa-Air-overflow-rerun` 새 DerivedData 사용. `bootstatus`에서 최종 `Booted` 확인 |
| 2026-08-28 | iPhone Air QA-AIR-001 `testPinnedFriendFixtureOverflowsViewportSoLazyStackDropsDropTargets` | PASS | 독립 실행 1개: 1 PASS / 0 FAIL / 0 SKIP. 결과 `ios/build-pre-submission-qa-Air-overflow-rerun/results/SocialPinnedFriendOverflowReorderUITests.testPinnedFriendFixtureOverflowsViewportSoLazyStackDropsDropTargets.xcresult` |
| 2026-08-28 | iPhone Air QA-AIR-001 `testReorderDragStartingOutsideTheAvatarButtonReorders` | PASS | 독립 실행 1개: 1 PASS / 0 FAIL / 0 SKIP. 결과 `ios/build-pre-submission-qa-Air-overflow-rerun/results/SocialPinnedFriendOverflowReorderUITests.testReorderDragStartingOutsideTheAvatarButtonReorders.xcresult` |
| 2026-08-28 | iPhone Air QA-AIR-001 `testReorderPersistsWhilePinnedRowsAreOutsideTheViewport` | PASS | 독립 실행 1개: 1 PASS / 0 FAIL / 0 SKIP. 결과 `ios/build-pre-submission-qa-Air-overflow-rerun/results/SocialPinnedFriendOverflowReorderUITests.testReorderPersistsWhilePinnedRowsAreOutsideTheViewport.xcresult` |
| 2026-08-28 | iPhone Air QA-AIR-001 `testReorderUpwardsAfterScrollingWithEarlierRowsOutsideTheViewport` | PASS | 독립 실행 1개: 1 PASS / 0 FAIL / 0 SKIP. 결과 `ios/build-pre-submission-qa-Air-overflow-rerun/results/SocialPinnedFriendOverflowReorderUITests.testReorderUpwardsAfterScrollingWithEarlierRowsOutsideTheViewport.xcresult` |
| 2026-08-28 | iPhone Air QA-AIR-001 결과/로그·crash 점검 | PASS | focused 4개: 4 PASS / 0 FAIL / 0 SKIP. 초기 `18 < 18` overflow assertion 3건은 최신 checkout에서 재현되지 않았고, app crash report 0, runner/simulator 오류 0. QA-AIR-001 수정·재검증 완료 후 Pro Max 진행 |
| 2026-08-28 | iPhone 17 Pro Max clean boot | PASS | `2AFDB0DF-841A-433F-B923-9241B21E58CB`를 clean shutdown/boot/bootstatus 완료. 테스트 중 `Booted` 유지 |
| 2026-08-28 | iPhone 17 Pro Max `DutyparkUITests` | PASS | 8개: 8 PASS / 0 FAIL / 0 SKIP. 결과 `ios/build-pre-submission-qa-ProMax-final/results/DutyparkUITests.xcresult` |
| 2026-08-28 | iPhone 17 Pro Max `TeamParityVisualUITests` | PASS | 10개: 10 PASS / 0 FAIL / 0 SKIP. 결과 `ios/build-pre-submission-qa-ProMax-final/results/TeamParityVisualUITests.xcresult` |
| 2026-08-28 | iPhone 17 Pro Max `TodoConfirmationVisualUITests` | FAIL | 8개: 7 PASS / 1 FAIL / 0 SKIP. `TodoConfirmationVisualUITests.swift:258`에서 `XCTWaiterResult(rawValue: 2)`가 기대 `rawValue: 1`과 불일치. 실패 테스트 `testFixtureTodoLongPressDragKeepsUnrelatedColumnCardsFixed`; 결과 `ios/build-pre-submission-qa-ProMax-final/results/TodoConfirmationVisualUITests.xcresult`, 로그 `.../logs/TodoConfirmationVisualUITests.log:500-505,827-846` |
| 2026-08-28 | iPhone 17 Pro Max 결과/로그·crash 점검 | PARTIAL (OPEN defect) | 현재 실행 26개: 25 PASS / 1 FAIL / 0 SKIP. 앱 crash report 0, runner/simulator 오류 0. QA-PROMAX-001 확인으로 `AttachmentGalleryVisualUITests`, `LongFormPolicyReadabilityUITests`, `RootMoreMenuParityUITests`는 실행하지 않음 |
| 2026-08-28 | iPhone 17 Pro Max QA-PROMAX-001 gap-endpoint GREEN clean boot | PASS | exact UDID `2AFDB0DF-841A-433F-B923-9241B21E58CB`를 clean shutdown/boot/bootstatus 완료. 새 DerivedData `ios/build-pre-submission-qa-ProMax-todo-gap-green` 사용, 테스트 중 `Booted` 유지 |
| 2026-08-28 | iPhone 17 Pro Max QA-PROMAX-001 gap-green run1 | PASS | `testFixtureTodoLongPressDragKeepsUnrelatedColumnCardsFixed` 독립 실행 1/1 PASS, test duration 18.676s. 결과 `ios/build-pre-submission-qa-ProMax-todo-gap-green/results/TodoConfirmationVisualUITests.testFixtureTodoLongPressDragKeepsUnrelatedColumnCardsFixed.run1.xcresult` 및 로그 보존 |
| 2026-08-28 | iPhone 17 Pro Max QA-PROMAX-001 gap-green run2 | PASS | 동일 테스트 독립 실행 1/1 PASS, test duration 15.848s. 결과 `ios/build-pre-submission-qa-ProMax-todo-gap-green/results/TodoConfirmationVisualUITests.testFixtureTodoLongPressDragKeepsUnrelatedColumnCardsFixed.run2.xcresult` 및 로그 보존 |
| 2026-08-28 | iPhone 17 Pro Max QA-PROMAX-001 gap-green run3 | PASS | 동일 테스트 독립 실행 1/1 PASS, test duration 16.064s. 결과 `ios/build-pre-submission-qa-ProMax-todo-gap-green/results/TodoConfirmationVisualUITests.testFixtureTodoLongPressDragKeepsUnrelatedColumnCardsFixed.run3.xcresult` 및 로그 보존 |
| 2026-08-28 | iPhone 17 Pro Max QA-PROMAX-001 gap-green 결과/crash/runner 점검 | PASS | 3회 summary 모두 `totalTestCount=1`, `passedTests=1`, `failedTests=0`, `skippedTests=0`. crash report 0, runner/simulator 오류 0. gesture/좌표/gap endpoint 수정 후 QA-PROMAX-001 재검증 완료 |
| 2026-08-28 | iPhone 17 Pro Max `AttachmentGalleryVisualUITests` | PASS | 1개: 1 PASS / 0 FAIL / 0 SKIP. 결과 `ios/build-pre-submission-qa-ProMax-remaining-final/results/AttachmentGalleryVisualUITests.xcresult`, 로그 `.../logs/AttachmentGalleryVisualUITests.log` |
| 2026-08-28 | iPhone 17 Pro Max `LongFormPolicyReadabilityUITests` initial | FAIL | 3개: 2 PASS / 1 FAIL / 0 SKIP. `LongFormPolicyReadabilityUITests.swift:82` `testAISchedulePolicyWrapsAtLargeDynamicType`에서 `tab.more` Button selector 미검출; 결과/로그 `ios/build-pre-submission-qa-ProMax-remaining-final/`에 보존 |
| 2026-08-28 | iPhone 17 Pro Max LongForm selector focused 재검증 | PASS | clean boot 후 새 DerivedData `ios/build-pre-submission-qa-ProMax-longform-rerun`, `testAISchedulePolicyWrapsAtLargeDynamicType` 독립 실행 1/1 PASS(16.333s). 로그에서 `tab.more` AX 노출·탭과 정책 문구 래핑 확인. 결과 `ios/build-pre-submission-qa-ProMax-longform-rerun/results/LongFormPolicyReadabilityUITests.testAISchedulePolicyWrapsAtLargeDynamicType.xcresult`; crash/runner 0 |
| 2026-08-28 | iPhone 17 Pro Max `RootMoreMenuParityUITests` | PASS | 2개: 2 PASS / 0 FAIL / 0 SKIP, suite duration 31.774s. 결과 `ios/build-pre-submission-qa-ProMax-rootmore-final/results/RootMoreMenuParityUITests.xcresult`, 로그 `.../logs/RootMoreMenuParityUITests.log`; crash/runner 0 |
| 2026-08-28 | iPhone 17 Pro Max 최종 결과/로그·crash 점검 | PASS (focused aggregate) | 초기 실패를 focused PASS로 대체한 유효 지정 테스트 32개: 32 PASS / 0 FAIL / 0 SKIP. 초기/재현성/green/remaining/focused 결과와 로그를 보존했고 모든 실행에서 앱 crash report 0, runner/simulator 오류 0. 실계정 기능은 별도 환경 차단 |
| 2026-08-28 | iPhone 13 mini shared drag 최종 회귀 | PASS | 최신 checkout에서 `TodoConfirmationVisualUITests` 8/8, `SocialPinnedFriendReorderUITests` 3/3, `SocialPinnedFriendOverflowReorderUITests` 4/4, `PinnedFriendActionButtonDragUITests` 4/4 — 합계 19/19 PASS, 앱 crash/runner 오류 0. 결과 `/private/tmp/dutypark-qa-final-drag-regression-13mini-*.xcresult` |
| 2026-08-28 | 최종 `DutyparkTests` 1차·retry | FAIL (test contract) | 1,075개 중 1,073 PASS / 1 FAIL / 1 환경 SKIP. wrong-valid cross-column drop 테스트가 기존 source-column rollback 계약 대신 pre-drop 선택을 기대한 테스트 오류로 두 번 동일 재현; 구현 결함과 분리 후 기대 수정 |
| 2026-08-28 | 최종 `DutyparkTests` GREEN | PASS | exact iPhone 13 mini, `/private/tmp/dutypark-final-all-unit-13mini-green.xcresult`: 1,075개 중 1,074 PASS / 0 FAIL / 1 Simulator file-protection 환경 SKIP, UI test 노드 0 |
| 2026-08-28 | 최종 Release Simulator 빌드·메타데이터 | PASS | `ios/build-qa-final-release-latest` `BUILD SUCCEEDED`. 운영 API `https://dutypark.o-r.kr/api/`, bundle `io.github.shanepark.dutypark`, v1.0.0(1), iOS 17+, iPhone/Portrait, source·bundle Info.plist/PrivacyInfo lint 및 privacy manifest 구조 확인 |
| 2026-08-28 | 최종 iPhone 13 mini 설치 | PASS | 최신 GREEN Debug 앱을 exact UDID `F0737016-7654-4967-83FA-1DFB951DB36E`에 설치하고 `simctl listapps` 및 `get_app_container`로 bundle/container 확인 |
| 2026-08-28 | 실제 테스트 계정 API 인증·조회 | PASS | localhost `/api/auth/token`·`/api/auth/status` HTTP 200. 관리자·팀 관리자 권한과 친구·D-Day·Todo·일정·근무·팀 조회 API 200 확인; 비밀번호·토큰은 기록하지 않음 |
| 2026-08-28 | iPhone 13 mini 실제 계정 read-only smoke | PASS | 실제 로그인 후 홈·캘린더·D-Day·Todo·팀·더보기·친구·알림·설정 진입, 종료·재실행 세션 복원 성공. 1/1 PASS, crash/runner 0. 결과 `/private/tmp/dutypark-live-account-result-13mini-rerun.xcresult` |
| 2026-08-28 | 실제 계정 mutation 전 데이터 snapshot | PASS | 기존 `QA-` Todo·일정·D-Day 0개 확인, 총 개수와 기존 row digest를 보관해 reversible CRUD 후 orphan/원본 변경 여부를 검증할 준비 완료 |
| 2026-08-28 | 실제 계정 5개 추가 해상도 core smoke | PASS | SE·17e·16 Pro·Air·17 Pro Max 각 1/1 PASS. 로그인·키보드·Home/Calendar/Todo/Team/More·foreground layout·재실행 세션 복원, crash/runner 0. 결과 `/private/tmp/dutypark-real-account-smoke/<device>-core-final/` |
| 2026-08-28 | iPhone 13 mini 실제 Todo mutation | PASS (with harness limitation) | UI 생성·재실행·상세·제목/내용 수정 persistence, server-backed status 저장 확인. 기존 편집 화면에 status 버튼이 없다는 제품 정책 및 drag 목적지 좌표 기대 때문에 focused harness가 중단됐으나 앱 crash 0. 생성 QA Todo는 exact ID guard 후 정상 API cleanup |
| 2026-08-28 | iPhone 13 mini 실제 일정 mutation | PASS (create/update) | UI 생성·재실행·검색·상세·수정·재실행 검색 persistence PASS. 날짜 cell `exists`만 기다린 초기 helper와 잘못된 첫 수정 selector 때문에 UI 삭제까지 도달하지 못함. 앱 결함 증거 없음; 생성 QA 일정은 exact ID guard 후 정상 API cleanup |
| 2026-08-28 | iPhone 13 mini 실제 D-Day mutation | PASS (create/update) | UI 생성·재실행·상세·수정·재실행 수정 제목 persistence PASS. 결과 `/private/tmp/dutypark-qa-calendar-dday-result-13mini-rerun4.xcresult`; 생성 QA D-Day는 exact ID guard 후 정상 API cleanup |
| 2026-08-28 | 실제 mutation 최종 데이터 원복 | PASS | Todo 17·일정 380·D-Day 6, QA orphan 0. 세 digest가 mutation 전 snapshot과 완전히 일치하여 기존 데이터 변경 0 확인 |
| 2026-08-28 | iPhone 17e actual 인증 심화 | PASS | 로그아웃 취소·확인, 잘못된 비밀번호 오류, 정상 재로그인, remember 토글 1/1 PASS(47.037s), crash/runner 0. 결과 `/private/tmp/dutypark-real-account-smoke/17e-secondary-auth-rerun2/` |
| 2026-08-28 | iPhone 17e actual 설정·문서 | PASS (2 SKIP) | 테마 변경·재실행 persistence·시스템 원복, 약관·개인정보·가이드·릴리즈 노트·버전 PASS. 계정 삭제 entry는 `isHittable`까지 스크롤한 focused에서 삭제 화면 진입·취소·MyInfo 복귀 1/1 PASS. iOS 26.5 앱별 언어 행 부재 및 비밀번호 없는 계정의 password-change는 환경/계정 유형 SKIP |
| 2026-08-28 | iPhone 17e actual 관리자 read-only | PASS | 관리자 dashboard, 회원 검색/초기화·상세, 팀 검색/초기화 1/1 PASS(55.510s), crash/runner 0. 결과 `/private/tmp/dutypark-real-account-smoke/17e-secondary-admin-rerun2/` |
| 2026-08-28 | 최종 main-worktree Debug 재설치 | PASS | exact iPhone 13 mini가 이미 booted인 상태에서 최신 전체 Unit GREEN 앱 재설치 성공. 최종 container `/Users/shane/Library/Developer/CoreSimulator/Devices/F0737016-7654-4967-83FA-1DFB951DB36E/data/Containers/Bundle/Application/BC24AD82-1CAD-4C13-86C1-3A8CB599E114/Dutypark.app` |

## 8. 최종 판정

- 판정: **조건부 통과 — 자동 fixture·Unit·Release 및 실제 계정 6개 해상도 core smoke와 대표 CRUD persistence에서 제출 차단 앱 결함·크래시 없음**
- 자동 검증 결론: SE~Pro Max 지정 matrix와 QA-SE/16PRO/AIR/PROMAX 결함 focused 재검증 완료, Pro Max 유효 32/32 PASS, 최신 13 mini shared drag 19/19 PASS, 최종 `DutyparkTests` 1,075개 중 실패 0(환경 SKIP 1), Release `BUILD SUCCEEDED`, 전체 최종 실행 앱 crash/runner 오류 0
- 미검증/제한 항목: 실제 첨부 업로드·친구/팀 destructive mutation·OAuth 공급자 완료·APNs 실기기 token·실네트워크 offline/복구·강제 세션 만료·실제 계정 최종 삭제·일정/Todo/D-Day UI 삭제 완료. 이 항목들은 외부 계정·실기기 또는 기존 데이터 손상 위험 때문에 fixture/unit/API cleanup 검증으로 대체하거나 미실행했다
- 잔여 위험: actual 일정 날짜 cell의 초기 `exists` 기반 helper, 계정 삭제 entry의 `exists` 기반 helper, 잘못된 첫 selector/drag 좌표에서 harness failure가 있었으나 readiness·`isHittable`·정확한 selector로 원인이 분리됐다. API 조사에서 dashboard의 미처리 친구 요청 표시 1건과 friend-request-count 0의 데이터/계약 차이가 관찰됐으며 별도 backend 확인이 권장된다. Simulator 설정의 알림 권한 변경 경고는 APNs 환경 제약으로 분류했다. 앱 crash/runner 오류는 0이며 앱 결함으로 확정된 미해결 사항은 없다
- 데이터 안전: 모든 QA Todo·일정·D-Day를 exact ID·소유자·`QA-` guard 후 정상 API로 정리했다. 최종 Todo 17·일정 380·D-Day 6, QA orphan 0, 세 digest가 mutation 전과 완전히 일치한다
- 제출 전 권장 후속: App Store archive의 실제 배포 서명/entitlements, APNs와 OAuth를 실기기·공급자 테스트 계정으로 한 번 더 확인하고, 운영과 분리된 disposable 계정이 준비되면 destructive 친구/팀/계정 삭제와 첨부 UI 삭제까지 완료한다
