# Dutypark iOS App Workboard

> 이 문서는 iOS 앱 전환 작업의 공용 컨텍스트이자 단일 작업 보드다. 모든 에이전트는 작업 시작 전 최신 내용을 읽고, 담당 범위·상태·산출물·충돌 가능 파일을 갱신한다.

## 0. 현재 상태 스냅샷 (2026-08-12)

> **현재 종합 상태: freeze3 최종 QA 진행 중.** SwiftUI 앱과 모바일 OAuth/APNs 서버 경로, 일반 사용자 기능 모듈은 작업트리에 구현되어 있다. freeze2 iOS 전체 테스트는 **105/105 성공**했고 final nits·Todo 첨부·core parity 보정과 targeted test도 완료했다. generic Simulator `build-for-testing`과 Personal Team local-only device app build는 성공했지만 연결 가능한 iPhone이 없어 설치는 대기 중이다. APNs 설치의 refresh-session 귀속 P0는 웹/PWA 세션 계약 영향 가능성 때문에 사용자 승인 전 구현하지 않는다. 아래 기능 매트릭스의 `[ ]`는 미착수를 뜻하지 않고 **완료 조건 검증 대기**를 뜻한다.

### 구현·회귀 검증이 확인된 범위

- [x] `ios/` SwiftUI iOS 17 프로젝트, 공통 `APIClient`, HttpOnly cookie/401 refresh/세션 복원, 이메일 인증, 5탭 내비게이션과 기능별 모듈을 구현했다.
- [x] `ASWebAuthenticationSession` + PKCE 기반 Kakao/Naver 로그인·연결·신규 SSO 가입 클라이언트와 additive 모바일 OAuth 서버 API를 구현했다.
- [x] 홈·캘린더·근무·일정·검색·D-Day·Todo·친구/가족·팀/팀 관리·알림·첨부·프로필/설정·정책/가이드·공개 진입점 코드를 구현했다.
- [x] APNs 설치 등록·해제, 발송, 수신·탭 이동·배지 코드를 Web Push 계약을 바꾸지 않는 additive 경로로 구현했다.
- [x] 모바일 OAuth/APNs/Web Push/알림 타깃 백엔드 테스트 118/118, 백엔드 회귀 범위 1,065개 중 1,044 성공·기존 skip 21·기능 assertion 실패 0을 확인했다. 단일 프로세스 말미 OOM이 난 팀 관리 suite는 새 JVM에서 19/19 성공했다.
- [x] MySQL 8.0에서 전체 73개 Flyway migration 신규 설치·V2.2.24 업그레이드·validate 73/73을 확인했다.
- [x] 기존 웹 frontend type-check, Vitest 99/99, production build, 5개 언어 release-note 검사를 통과했다.
- [x] freeze2 최신 iOS 전체 **105/105**를 통과했다.
- [x] P1 세션·OAuth·Push preference·Social sync·Calendar·Team·Settings Guide/deeplink/share/toolbar·Profile sync·attachment safety/discard guard 보정과 각 targeted test를 완료했다.
- [x] `docker-compose.yml`에 기존 `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_PRIVATE_KEY` 전달을 최소 연결했다.
- [x] Personal Team을 사용한 local-only device app build를 성공시켜 코드 서명 가능한 앱 산출물을 확인했다.
- [x] final nits, Todo 첨부·discard 흐름, core 기능 동등성 보정과 targeted test를 완료했다(Calendar **17/17** 포함).

### 진행 중 또는 완료 확인이 남은 범위

- [ ] 기능 동등성 매트릭스 전 항목의 API fixture·권한·쓰기 후 재조회·웹 교차 검증을 완료한다.
- [ ] 현지화 String Catalog의 5개 언어 런타임 표시, 테이블/폼 문구, 라이트·다크·Dynamic Type·VoiceOver를 최종 확인한다.
- [ ] freeze2 105/105 이후 freeze3 최종 clean QA와 마지막 기능 동등성 감사를 완료한다.
- [ ] APNs installation을 현재 refresh session에 귀속하는 P0 변경의 웹/PWA 영향·최소 대안·회귀안을 사용자에게 제시하고 승인받는다.
- [ ] iPhone 13 mini·iPhone 16 Pro 화면·5개 언어·접근성 시각 QA를 완료한다.
- [ ] 실제 iPhone에서 서명·설치·세션 복원·Kakao/Naver 로그인·첨부·알림·APNs 수신 E2E를 완료한다.
- [ ] App Store 심사 범위인 실제 계정 삭제, Sign in with Apple 적용 여부, 개인정보/UGC 항목을 사용자와 별도 확정한다. 이는 웹 기능 동등성보다 넓은 출시 준비 항목이다.

### 외부 준비·운영 연결 게이트

- [ ] 배포용 유료 Apple Developer Team, App ID Push capability, development/distribution provisioning, APNs `.p8`·Key ID·Team ID와 App Store Connect 앱 레코드를 준비한다. Personal Team local-only build는 성공했지만 배포·실제 APNs 자격증명을 대신하지 않는다.
- [ ] Kakao Developers에 기존 웹 callback을 유지하면서 `https://dutypark.o-r.kr/api/auth/mobile/oauth/callback/kakao`를 추가하고 REST key·동의항목·Client Secret ON/OFF를 확인한다.
- [ ] Naver Developers에 기존 웹 callback을 유지하면서 `https://dutypark.o-r.kr/api/auth/mobile/oauth/callback/naver`를 추가하고 Client ID/Secret·서비스 상태·테스트 계정을 확인한다.
- [x] `docker-compose.yml`이 `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_PRIVATE_KEY`를 앱 컨테이너에 전달하도록 최소 연결했다. 자격증명은 저장소에 커밋하지 않는다.
- [ ] 운영 proxy의 public scheme/host 전달과 실제 provider/APNs 자격증명으로 smoke test한다.
- [ ] `https://dutypark.o-r.kr/.well-known/apple-app-site-association`은 현재 HTTP 200이나 `text/html` SPA fallback이다. 올바른 AASA 제공은 웹/배포 영향이 있어 사용자 협의 후 적용한다.

> 현재 iOS/백엔드 변경은 작업트리의 미커밋·미배포 상태다. `dutypark://oauth/callback`은 공급자 콘솔 callback이 아니라 서버가 iOS 앱으로 돌아올 때 쓰는 custom scheme이다.

## 1. 사용자 목표

- 기존 웹 시스템과 PWA 사용 경험은 그대로 유지한다.
- 관리자 기능을 제외한 일반 사용자용 웹 기능을 iOS 앱에서도 완전히 동일하게 사용할 수 있게 한다.
- 현재 반응형 웹/PWA의 화면, 정보 구조, 사용자 흐름을 iOS 앱의 기준선으로 삼는다.
- 디자인과 UI/UX는 기존 상태를 최대한 유지하되, iOS 네이티브 앱에서 명확한 이점이 있는 상호작용은 선별 도입한다.
- SwiftUI 네이티브, iOS 17 이상, iPhone 전용 앱으로 구현한다.
- Kakao/Naver 로그인을 앱 범위에 포함하고 관리자 기능은 기존 웹 전용으로 유지한다.
- 현행 API로 구현 가능한 범위부터 만들되, 기능 완전 일치와 iOS 대응에 필요한 서버 코드 변경은 허용한다.
- 오프라인 기능은 후순위로 두며 1차 범위에서는 온라인 사용을 기준으로 한다.
- 내부 빌드와 시뮬레이터 검증을 거쳐 App Store 제출 준비가 된 상태까지 진행한다. TestFlight와 App Store의 실제 배포 순서는 별도 결정한다.

## 2. 운영 원칙

> **최우선 안전 규칙:** 웹과 iOS 앱은 계속 병행 운영한다. 기존 웹 서비스에 사이드이펙트가 생길 가능성이 있는 변경을 발견하면 즉시 작업을 멈추고, 영향 범위·대안·웹 회귀 검증안을 사용자에게 제시해 승인받은 뒤 재개한다.

> **최우선 구현 원칙:** 오버엔지니어링하지 않는다. 현재 웹 수준 이상으로 불필요한 방어 로직, 추상화, 환경변수, 상태를 선제 추가하지 않으며 변경 범위와 구현을 가장 작고 단순하게 유지한다.

1. 메인 에이전트는 직접 구현하지 않고 작업 설계, 분배, 충돌 조정, 사용자 소통을 담당한다.
2. 독립적인 조사·설계·구현·검증은 서브에이전트가 병렬로 진행한다.
3. 같은 파일을 수정할 가능성이 있는 작업은 동시에 진행하지 않는다. 작업표의 `충돌 가능 파일`을 먼저 확인한다.
4. 각 에이전트는 착수 전에 담당 행을 등록하고, 완료 시 산출물과 검증 결과를 기록한다.
5. 기본값은 기존 endpoint, 쿠키, API, OAuth, PWA, Web Push 계약을 변경하지 않는 것이다. iOS 지원은 별도 endpoint·DTO·서비스·저장 모델 등 **additive 경로**로 구현한다.
6. iOS 기능 완전 일치에 필요한 서버 변경은 허용하지만, 기존 웹 계약을 수정·대체·삭제하는 방식은 사전 사용자 승인 없이는 진행하지 않는다.
7. 웹 사이드이펙트 가능성이 확인되면 담당 작업을 `차단`으로 바꾸고 영향 범위, additive 대안과 공통 변경 대안, 각각의 장단점, 웹 회귀 검증안을 `질문 / 리스크`에 기록해 승인받는다.
8. 모든 백엔드 공유 변경은 영향받는 기존 웹 경로의 회귀 테스트까지 통과해야 `완료`로 표시할 수 있다.
9. 실제 요구나 재현된 문제가 없는 확장 포인트, 다중 환경, 상태 기계, 보안 인프라는 만들지 않는다. 필요가 확인된 시점에 가장 작은 변경으로 도입한다.
10. 저장소의 `AGENTS.md`와 인접 코드·테스트의 기존 패턴을 따른다.
11. 개발 서버는 사용자가 명시적으로 요청한 경우에만 실행한다.
12. 자동 커밋하지 않는다.

## 3. 상태와 보드 갱신 규칙

상태는 `대기`, `진행 중`, `검토 필요`, `승인 대기`, `차단`, `완료`만 사용한다. 독립 검토와 사용자 승인이 모두 필요하면 `검토 필요 / 승인 대기`로 병기한다.

- `대기`: 선행 작업 또는 배정을 기다림
- `진행 중`: 담당 에이전트가 현재 수행 중
- `검토 필요`: 산출물은 있으나 통합 또는 사용자 결정이 필요함
- `승인 대기`: 안전 게이트에 따라 사용자 사전 승인을 받기 전에는 재개할 수 없음
- `차단`: 외부 결정이나 해결되지 않은 의존성 때문에 진행 불가
- `완료`: 산출물과 필요한 검증이 모두 끝남

보드 갱신 순서:

1. 작업표에 담당자와 범위를 등록하고 상태를 `진행 중`으로 변경한다.
2. 충돌 가능 파일이 다른 `진행 중` 작업과 겹치면 메인 에이전트에게 조정을 요청한다.
3. 중요한 발견은 즉시 `질문 / 리스크`에 추가한다.
4. 결정이 내려지면 `결정 로그`에 날짜, 결정, 근거, 영향을 기록한다.
5. 완료 시 산출물 경로, 실행한 검증, 남은 제약을 작업표와 체크리스트에 반영한다.
6. 웹 사이드이펙트 가능성이 있는 작업은 `차단` 처리하고 사용자 승인 식별자를 기록하기 전까지 구현을 재개하지 않는다.

## 4. 단계별 체크리스트

### 단계 0 — 현행 시스템 조사 및 기준선 확정

- [x] 저장소 구조, 인증, API, 푸시, 파일 업로드, 실시간/폴링 동작을 조사한다.
- [x] 모바일 반응형 웹/PWA의 전체 화면과 주요 사용자 흐름을 목록화한다(정적 분석 기준).
- [ ] iPhone 16 Pro(402×874), iPhone 13 mini(375×812)에서 현행 UI를 확인한다.
- [x] iOS 앱 기술 방식 후보를 비교하고 사용자와 최종 방향을 결정한다.
- [x] 현행 API만으로 가능한 기능과 서버 변경이 필요한 기능을 구분한다.
- [x] 보안, App Store 심사, 개인정보, 서드파티 OAuth 제약을 조사한다.
- [x] 1차 제품 범위와 완료 기준을 사용자와 확정한다.

### 단계 1 — iOS 프로젝트 기반

- [ ] iOS 프로젝트 위치, 최소 지원 iOS 버전, 번들 식별자, 서명 전략을 확정한다.
- [x] 앱 구조, 의존성 주입, 네트워크 계층, 상태 관리, 내비게이션 기준을 만든다.
- [ ] 개발/스테이징/운영 환경 구성을 분리하고 비밀정보가 저장소에 들어가지 않게 한다.
- [x] 공통 디자인 토큰, 타이포그래피, 다크 모드, 접근성 기준을 정의한다.
- [x] `ko`, `en`, `ja`, `zh`, `es` 현지화 구조를 마련한다.
- [ ] 네트워크 오류, 인증 만료, 오프라인 상태의 공통 처리 방식을 구현한다.

### 단계 2 — 인증 및 계정

- [x] 현행 쿠키/Bearer 인증 흐름과 iOS 보안 저장소 연동 방식을 결정한다.
- [x] 로그인, 로그아웃, 토큰 갱신, 세션 만료 흐름을 구현한다.
- [ ] Kakao/Naver OAuth의 네이티브 앱 리디렉션과 서버 호환성을 검증한다.
- [x] 보조 계정, 가장, 회원 설정 등 기존 계정 기능의 지원 범위를 구현한다.
- [ ] 키체인 저장, 전송 보안, 로그 민감정보 노출을 검증한다.

> OAuth 코드·단위 테스트는 구현됐으며 위 항목은 Kakao/Naver 콘솔 등록과 실제 iPhone E2E까지 끝난 뒤 완료 처리한다. 보조 계정·가장 UI/API와 만료·복귀 P1 보정은 targeted test를 통과했다. HttpOnly 인증 cookie는 앱이 토큰 값을 직접 저장하지 않고 shared cookie storage로 관리한다.

### 단계 3 — 핵심 기능 MVP

- [ ] 홈/캘린더/일정 조회를 구현한다.
- [ ] 일정 생성·수정·삭제와 시간 파싱 상태 표시를 구현한다.
- [ ] 친구, 팀, 공유 및 권한 기반 UI를 구현한다.
- [ ] 할 일 기능을 구현한다.
- [ ] 프로필과 기본 설정을 구현한다.
- [ ] 첨부파일 업로드·조회·삭제를 컨텍스트별로 검증한다.
- [ ] 다국어, 라이트/다크 모드, Dynamic Type, VoiceOver를 점검한다.

> 위 기능 모듈의 화면·API 코드는 구현돼 있고 P1 및 final nits 보정과 targeted test도 끝났다. 체크는 freeze3 최종 QA와 실제 기기 검증까지 통과한 뒤 완료로 바꾼다.

### 단계 4 — iOS 네이티브 이점 도입

- [x] 네이티브 푸시(APNs) 전략과 기존 Web Push 공존 방식을 결정한다.
- [x] 앱 배지와 읽지 않은 알림 상태 동기화를 구현한다.
- [x] 사진 선택, 카메라, 공유 시트 등 네이티브 첨부 경험을 검토한다.
- [ ] 햅틱, 스와이프 액션, 컨텍스트 메뉴 등 명확한 이점이 있는 상호작용만 도입한다.
- [ ] 위젯, 딥 링크, Spotlight, App Intents는 MVP 이후 우선순위로 평가한다.
- [ ] 백그라운드 갱신과 알림 처리의 전력·데이터 사용량을 검증한다.

### 단계 5 — 통합·회귀·배포 준비

- [x] 단위, 통합, UI 테스트를 구축하고 핵심 흐름을 자동화한다.
- [ ] 지원 기기/OS 매트릭스에서 실제 기기 검증을 수행한다.
- [ ] 기존 웹/PWA의 인증, 푸시, 일정, 첨부 기능 회귀 테스트를 수행한다.
- [ ] 개인정보 처리, 권한 문구, 계정 삭제, App Store 심사 항목을 점검한다.
- [ ] TestFlight 배포, 크래시/로그/분석, 롤백 절차를 준비한다.
- [ ] 출시 범위, 알려진 제한, 운영 대응 문서를 확정한다.

## 5. 에이전트 작업표

> 담당자는 자신의 행만 수정하는 것을 원칙으로 한다. 파일 범위가 미정이면 착수 전에 먼저 확정한다.

| ID | 작업 | 담당 | 상태 | 산출물 | 충돌 가능 파일 |
|---|---|---|---|---|---|
| COORD-001 | 전체 계획·분배·사용자 소통·충돌 조정 | 메인 에이전트 | 진행 중 | 이 작업 보드, 통합 계획, 결정 요청 | `IOS_APP_WORKBOARD.md` |
| BOARD-001 | 공용 작업 보드 초안 작성 | workboard 에이전트 | 완료 | `IOS_APP_WORKBOARD.md` | `IOS_APP_WORKBOARD.md` |
| AUDIT-001 | 저장소 구조 및 현행 API/도메인 조사 | 조사 서브에이전트 | 완료 | §6.2 서버 무변경 범위, §6.6 API·데이터 주의점 | 백엔드 소스(읽기 전용) |
| AUTH-001 | 인증·OAuth·세션의 iOS 호환성 조사 | 인증 서브에이전트 | 완료 | §6.3 인증·OAuth 경계 | 인증 관련 백엔드/프론트 파일(읽기 전용) |
| UX-001 | 현행 모바일 웹/PWA 화면·흐름 감사 | UX 서브에이전트 | 완료 | §6.5 모바일 웹·UI 감사 | 프론트 파일(읽기 전용) |
| ARCH-001 | iOS 기술 방식 및 아키텍처 제안 | 아키텍처 서브에이전트 | 완료 | §6.1 iOS 기반 권고, §6.7 도구·CI, 구현된 `ios/` 프로젝트 | `ios/` 프로젝트·공통 기반 |
| API-001 | API 계약 및 서버 최소 변경 갭 분석 | API 서브에이전트 | 완료 | §6.2, §6.3, §6.4, §6.6 | 컨트롤러/DTO/보안 설정(읽기 전용) |
| PUSH-001 | APNs·Web Push 공존 전략 조사 | 푸시 서브에이전트 | 완료 | §6.4 APNs와 Web Push 공존안 | 푸시 백엔드, 서비스 워커, iOS 앱(읽기 전용) |
| B1 | iOS 프로젝트 골격·테스트 타깃 | B1 구현 에이전트 | 완료 | `ios/` 앱·단위·UI 테스트 타깃, 5탭 현지화·검증 | `ios/` 프로젝트·공통 기반 |
| B2 | 공통 APIClient·이메일 쿠키 세션 | API/Auth 구현 에이전트 | 검토 필요 | `APIClient`, shared cookie storage, 단일 refresh gate, 세션 복원, 이메일 인증 | iOS 네트워크·인증 모듈 |
| B3-SERVER | 모바일 OAuth 서버 기반 | B3 서버 구현 에이전트 | 완료 | additive 서버 경로, 최소 TX 경계, mobile+web OAuth 34/34 | 백엔드 모바일 인증 모듈 |
| B3-IOS | 모바일 OAuth 앱 클라이언트 연결 | OAuth iOS 구현 에이전트 | 검토 필요 | `ASWebAuthenticationSession`, PKCE, callback 검증, code exchange·가입·연결; 실제 provider E2E 대기 | iOS OAuth 모듈 |
| B4 | 일반 사용자 웹 기능 완전 일치 | 기능별 iOS 구현·통합 에이전트 | 진행 중 | 기능별 SwiftUI 화면·API 연동·테스트; 2차 parity/현지화/최종 QA 진행 | iOS 기능 모듈 전반 |
| B5 | APNs·계정 삭제·App Store 심사 준비 | APNs 서버·iOS 구현 에이전트 | 진행 중 | additive APNs 등록·발송·수신 구현; 실제 서명·기기·심사 항목 대기 | 백엔드 알림/계정·iOS 설정/CI |
| QA-001 | 테스트 전략 및 회귀 검증 조사 | QA 서브에이전트 | 완료 | §6.8 QA 기준선, 생성된 단위·UI 테스트 타깃 | 테스트 파일·설정 파일 |
| QA-FINAL | 통합 freeze·최종 clean QA·기능 동등성 감사 | 통합/QA 에이전트 | 진행 중 | freeze2 iOS 105/105 성공; final nits/Todo 첨부/core parity targeted test 성공; freeze3 최종 QA 진행 | iOS 전반·테스트 결과 |

## 6. 1차 조사 통합 요약

> 이 절은 구현 전 기준선을 보존한 초기 조사 기록이다. 구현 후 사실과 현재 상태는 §0, §7의 최신 통합 기록, §9 리스크를 우선한다.

### 6.1 확정된 iOS 기반

- 완전 네이티브 **SwiftUI 앱**을 저장소의 `ios/`에 추가한다.
- 최소 지원 버전은 **iOS 17**, 언어 모드는 **Swift 6**이며 1차는 iPhone 전용이다.
- 플랫폼 기능은 Apple SDK를 우선 사용하고, 외부 의존성이 꼭 필요한 경우 Swift Package Manager(SwiftPM)로 관리한다.
- 구현 방식은 네이티브로 하되, 시각 체계는 Dutypark 브랜드를 유지하고 iOS 탐색·접근성 관례를 결합하는 **브랜드 하이브리드 UI**를 적용한다. 여기서 하이브리드는 웹뷰 기술 방식이 아니라 디자인 원칙을 뜻한다.

### 6.2 서버 무변경으로 가능한 1차 범위

현행 API와 `URLSession` 쿠키 세션을 이용하는 전제에서 다음 기능은 서버 변경 없이 구현 가능하다.

- 이메일 로그인과 HttpOnly 쿠키 기반 세션
- 홈, 캘린더, 근무, 일정
- Todo
- 친구, 팀
- 인앱 알림 조회·읽음 처리
- 첨부파일 조회·업로드·편집

따라서 첫 구현은 이메일 로그인과 위 기능을 묶은 **cookie-MVP**로 시작했다. 현재 공통 cookie client와 인증 흐름은 구현됐으며 실제 운영 서버·iPhone에서 저장·갱신·만료 E2E만 남았다.

### 6.3 인증·OAuth 경계

- Kakao/Naver OAuth는 `ASWebAuthenticationSession`의 브라우저 쿠키와 앱 `URLSession` 쿠키 저장소가 자동으로 이어지지 않으므로 현행 흐름을 그대로 재사용하기 어렵다.
- 최소 서버 변경안은 짧은 수명의 **1회용 authorization code + PKCE + state + redirect allowlist**를 도입하는 것이다.
- 앱이 code를 교환하는 최초 응답에서 기존 access/refresh **HttpOnly 쿠키**를 설정해 이후 API 세션 모델을 웹과 동일하게 유지하는 방식을 권고한다.
- OAuth `state` 검증과 callback 처리에는 기존 보안 부채가 있어 iOS 전용 흐름을 추가하기 전에 함께 정리해야 한다.
- 현재는 위 권고대로 PKCE/state/1회용 code 기반 모바일 전용 API와 iOS 클라이언트가 구현됐고, 기존 웹 OAuth 경로는 유지됐다.

### 6.4 APNs와 Web Push 공존안

- 기존 VAPID Web Push는 웹/PWA용으로 그대로 유지한다.
- 네이티브 앱 푸시에는 별도의 APNs 지원이 필요하다.
- 최소 서버 확장 범위는 앱 설치 단위를 나타내는 installation 테이블, APNs 토큰 등록·해제 API, 알림 채널별 dispatcher다.
- 인앱 알림의 서버 상태를 단일 원천으로 유지하고, Web Push/APNs는 각각 전달 채널로만 취급해 읽음 상태와 배지 중복을 방지한다.
- 현재는 위 최소 확장이 구현됐으며 Apple 자격증명·서명·실기기 발송 검증이 남았다.

### 6.5 모바일 웹·UI 감사

- 로컬 개발 서버가 실행 중이지 않아 브라우저 접속은 `localhost refused`로 실패했다. 실제 iPhone 크기의 브라우저 검증은 아직 완료되지 않았다.
- 정적 분석상 5탭 내비게이션, safe area, 44px 이상 터치 영역, 스와이프 대응은 양호하다.
- 화면의 정보 구조와 브랜드는 유지하되, SwiftUI의 탭·내비게이션·시트·스와이프·Dynamic Type·VoiceOver 관례를 적용하는 브랜드 하이브리드 UI가 적합하다.

### 6.6 API·데이터 주의점

- 일정 검색 요청 DTO가 프론트엔드와 백엔드에서 일치하지 않는 부분이 있어 iOS 모델을 고정하기 전에 계약 확인이 필요하다.
- 첨부 편집 요청에서 `orderedAttachmentIds`가 누락되면 기존 첨부 전체 삭제로 해석될 수 있으므로 클라이언트가 항상 명시적으로 전송하고 계약 테스트로 보호해야 한다.
- iPhone 사진의 HEIC는 서버 호환성을 위해 앱에서 JPEG 변환을 고려한다.
- 앱의 파일 허용 크기 50MB와 nginx 제한 10MB가 불일치하므로 사용자 노출 제한과 운영 설정을 하나로 맞춰야 한다.
- timezone 정보가 없는 `LocalDateTime` 계약은 기기/서버 시간대가 달라질 때 오해 가능성이 있으므로 명시적인 직렬화 규칙과 fixture 테스트가 필요하다.

### 6.7 도구·프로젝트·CI

- 현재 환경에서 Xcode 26.6과 Swift 6.3.3을 사용할 수 있다.
- Xcode 프로젝트는 filesystem-synchronized groups를 사용해 파일 추가 충돌을 줄이는 방식을 권고한다.
- iOS 빌드·테스트는 별도 `ios.yml` 워크플로로 분리하는 방식을 권고한다.
- 현 CI 구성에서는 iOS-only 변경이 `main`에 병합되어도 서버 재배포가 발생하므로 경로 필터 또는 배포 조건 정리가 필요하다.

### 6.8 QA 기준선

- 가장 먼저 이메일 로그인, 쿠키 저장, refresh, 앱 재실행 후 세션 복원을 확인하는 cookie POC를 만든다.
- API 모델은 fixture 기반 contract test로 프론트/백엔드 불일치와 날짜·첨부 계약을 고정한다.
- iPhone 13 mini와 iPhone 16 Pro를 필수 화면 검증 대상으로 둔다.
- 한국어, 영어, 일본어, 중국어, 스페인어와 라이트/다크 모드, Dynamic Type, VoiceOver를 함께 검증한다.

### 6.9 App Store 준비 갭

- App Store 제출 전 앱 안에서 접근 가능한 계정 삭제 API와 화면이 필요하다.
- Kakao/Naver와 같은 제3자 로그인을 제공하면 Sign in with Apple 제공 요건을 검토해야 하며, 현재 범위에서는 사실상 함께 준비하는 것이 안전하다.
- 개인정보 처리방침의 인증 설명이 실제 쿠키 인증 방식과 일치하지 않아 수정이 필요하다.
- 사용자 생성 콘텐츠(UGC)가 노출되는 범위에는 신고·차단·운영 대응 요건을 검토한다.

## 7. 실행 배치

> 1차 목표는 B1~B5를 거쳐 내부 빌드와 시뮬레이터 검증을 완료하고 App Store 제출 준비 상태에 도달하는 것이다. TestFlight와 App Store의 실제 배포 순서는 아직 결정하지 않았다.

| 배치 | 범위 | 선행 조건 | 병렬화·충돌 기준 | 완료 조건 | 상태 |
|---|---|---|---|---|---|
| B1 | `ios/` SwiftUI 프로젝트 골격, 앱·단위·UI 테스트 타깃, 공통 디자인/현지화 기반 | 사용자 플랫폼 결정 완료 | 프로젝트 파일 소유 에이전트 1명; 테스트 fixture는 분리 가능 | generic build, iPhone 13 mini unit 2/UI 1, 5탭 이동·현지화 검증 | 완료 |
| B2 | 필요한 범위의 공통 `APIClient`, HttpOnly 쿠키 저장·refresh·복원, 이메일 로그인 | B1 | 네트워크·인증 공통 파일은 단일 담당; 선제 protocol/DI/router 추상화 금지 | cookie POC와 이메일 인증 계약 테스트 통과 | 검토 필요 |
| B3 | 모바일 OAuth 서버 code 교환과 iOS Kakao/Naver 연결 | 서버 기반 완료; 앱 클라이언트 구현 완료 | additive 서버 경로와 iOS 클라이언트 통합; 기존 OAuth 계약 영향 시 승인 게이트 | 서버 mobile+web 34/34와 앱 성공·취소·실패·exchange 검증 | 서버·앱 구현 완료 / 외부 E2E 대기 |
| B4 | 관리자 제외 일반 사용자 웹 기능 완전 일치 | B2; 소셜 진입점은 B3 | 홈/캘린더·근무/일정·Todo·친구/팀·알림/첨부·프로필/설정을 파일 소유권별 병렬 구현 | 기능 매트릭스 전 항목과 5개 언어·접근성 검증 | 진행 중 |
| B5 | APNs, 앱 내 계정 삭제, 개인정보/UGC/심사 갭, 배포·CI 준비 | B3, B4 핵심 흐름 | APNs 서버·앱, 계정 삭제 서버·앱, 심사/CI를 분리; 기존 Web Push·계정 계약 영향 시 승인 게이트 | App Store 준비와 기존 Web Push·웹 계정 경로 회귀 검증 통과 | 진행 중 / 외부 준비 필요 |

### B1 구현·검증 기록

상태: **완료**. 사용자 품질에 직접 필요한 최소 보정을 반영하고 다시 검증했다.

산출물:

- `ios/Dutypark.xcodeproj`와 공유 scheme
- SwiftUI 앱 진입점, 5탭 root, 초기 Home/Calendar/Todo/Team/Settings placeholder 화면(B4에서 실제 기능 화면으로 교체됨)
- 5탭 domain과 탭별 화면 title 경계
- String Catalog 기반 현지화 골격
- 앱 단위 테스트와 UI 테스트 타깃
- 사용되지 않던 미래용 configuration/metadata type 제거

검증:

- generic iOS Simulator build 성공
- iPhone 13 mini 시뮬레이터에서 unit test **2/2 성공**
- iPhone 13 mini 시뮬레이터에서 UI test **1/1 성공**

완료된 최소 보정:

- [x] 작은 탭 슬롯용 short key와 화면 title key를 분리해 5개 언어에 적용
- [x] 실제 5개 탭 이동과 각 화면 도달을 검증하는 UI test 추가
- [x] 현재 사용하지 않는 미래용 type 제거

필요 시 도입하는 후순위 항목:

- Debug/Staging/Prod 다중 configuration은 실제로 복수 서버 환경을 운영할 때 추가한다.
- bundle identifier와 Development Team은 실제 기기 서명 또는 TestFlight 준비 시 확정한다.
- DI, session 추상화, router, design token scaffolding은 실제 기능 구현에서 중복이나 교체 필요가 확인될 때 가장 작은 형태로 도입한다.

### B3 모바일 OAuth 서버·앱 구현 및 외부 E2E 후속

상태: **서버 기반 완료 / iOS OAuth 클라이언트·단위 테스트 구현 완료 / Kakao·Naver 외부 E2E 대기**.

현재 산출물과 증거:

- 모바일 전용 controller, service, provider gateway, transaction entity/repository, DTO/properties, cleanup scheduler와 additive DB migration 구현
- 모바일 OAuth service의 class-level transaction 제거
- 기존 `stateConsumedAt`을 재사용한 짧은 claim transaction → provider HTTP outside transaction → 짧은 finalize transaction 적용
- provider 취소는 고정 callback의 `error=oauth_cancelled`, provider code 누락·호출 실패는 `error=provider_failed`로 복귀
- 앱 callback은 `dutypark://oauth/callback`으로 고정
- state TTL **5분**, exchange code TTL **2분**을 코드 상수로 유지
- 새로 추가했던 mobile OAuth 환경변수 4개 제거
- 기존 `signupUuid`, 웹 OAuth, HttpOnly 쿠키, SSO signup 계약 유지
- 기존 웹 OAuth controller/service, 기존 쿠키 계약, 기존 SSO signup 계약 코드는 변경하지 않음
- 모바일+기존 웹 OAuth 타깃 테스트 **34/34 성공**
- `git diff --check` 통과
- 최신 백엔드 회귀 범위는 **1,065개 중 1,044 성공 / 기존 21 skip / 기능 assertion 실패 0**이다. 단일 프로세스 말미 OOM이 난 팀 관리 suite는 새 JVM에서 **19/19 성공**했다.
- 모바일 OAuth·APNs·Web Push·알림 타깃 테스트는 **118/118 성공**했다.

해결한 웹 안전 위험:

- provider HTTP 동안 DB transaction과 row lock을 유지하던 구조를 위의 짧은 claim/finalize transaction으로 분리했다.

의도적으로 구현하지 않은 항목:

- 별도 `PENDING/PROCESSING/COMPLETED/FAILED` 상태 기계
- mobile-only signup credential
- custom rate-limit 인프라와 관련 환경변수·발급 상한
- impersonation 전용 분기와 unique race 격리 같은 추가 정책
- FK cascade와 선제 index 추가

이 항목들은 실제 문제나 운영 요구가 확인될 때 별도 영향 분석 후 필요한 최소 범위로만 도입한다.

iOS 클라이언트 및 외부 후속:

- [x] B2 공통 `APIClient`와 이메일 쿠키 세션 연결
- [x] `ASWebAuthenticationSession`으로 authorize URL 열기
- [x] 고정 `dutypark://oauth/callback` 성공·취소·실패 처리
- [x] PKCE verifier를 이용한 one-time code exchange와 기존 HttpOnly 쿠키 처리
- [x] 신규 SSO 가입과 Kakao/Naver 계정 연결 흐름 구현
- [ ] Kakao/Naver 콘솔에 운영 callback을 추가하고 실제 iPhone에서 기존·신규·취소·실패를 E2E 검증

### 백엔드 공유 변경 공통 완료 게이트

백엔드 공유 코드를 수정하는 모든 배치와 하위 작업에는 다음 완료 조건을 추가한다.

1. 기존 endpoint·쿠키·API·OAuth·PWA·Web Push 계약이 불변임을 diff와 계약 테스트로 확인한다.
2. iOS 전용 additive 경로가 기존 웹 요청과 분리되어 있음을 확인한다.
3. 영향받는 백엔드 타깃 테스트와 기존 웹 클라이언트의 타입 검사·빌드·관련 테스트를 실행한다.
4. 인증 변경은 기존 웹 이메일 로그인, refresh, 로그아웃, Kakao/Naver OAuth 성공·실패 흐름을 회귀 검증한다.
5. 알림 변경은 기존 PWA 구독, Web Push 발송, 읽음 상태와 배지 동작을 회귀 검증한다.
6. 사이드이펙트 가능성이 남아 있으면 작업을 완료하지 않고 사용자 승인 게이트로 전환한다.

### B4 병렬 기능 스트림

- B4-A: 홈, 5탭 셸, 캘린더
- B4-C: Todo
- B4-D: 친구, 팀, 공유·권한
- B4-E: 인앱 알림, 읽음 상태, 배지
- B4-F: 첨부파일, 사진 선택, HEIC→JPEG, 업로드 제한
- B4-G: 프로필, 보조 계정, 가장, 일반 사용자 설정

### 최신 통합 구현·검증 기록

- `Core/Networking`, `Core/Auth`, `Core/Navigation`과 Home, Calendar, Todo, Social, Team, Notifications, Attachments, Settings, Guest/Public 기능 모듈이 통합돼 있다.
- Guest/Public targeted test **5/5**를 포함한 기능별 targeted test가 통과했다.
- 통합 중 발생한 `RootTabView`의 `!await` Swift 구문 오류는 `!(await ...)`로 수정됐고 최신 generic `build-for-testing`은 **TEST BUILD SUCCEEDED**다.
- 5개 언어 String Catalog 구조와 번역 키는 존재하며, 최근 테이블·폼 현지화 통합 후 런타임 표시를 최종 확인 중이다.
- freeze2 최신 iOS 전체 **105/105**가 성공했다.
- 2차 감사에서 나온 세션·OAuth·Push preference·Social sync·Calendar·Team·Settings Guide/deeplink/share/toolbar·Profile sync·attachment safety/discard guard P1을 보정하고 각 targeted test를 통과했다.
- final nits, Todo attachment/discard, core parity 보정과 targeted test(Calendar **17/17** 포함)를 완료했다.
- 현재 freeze3 최종 clean QA와 마지막 기능 동등성 감사가 진행 중이다.
- APNs installation의 refresh-session 귀속 P0는 기존 웹/PWA refresh token 계약에 닿을 수 있어 사용자 승인 대기이며 아직 구현하지 않았다.
- Personal Team local-only device app build는 성공했다. 연결 가능한 iPhone이 없어 설치는 대기 중이며 배포용 유료 Team/provisioning과 provider/APNs key는 외부 준비가 필요하다.

## 8. 결정 로그

| 날짜 | ID | 결정 | 근거 | 영향 |
|---|---|---|---|---|
| 2026-08-12 | D-001 | 기존 웹/PWA는 유지하고 iOS 앱을 추가한다. | 사용자 요구 | 웹 기능 회귀 방지가 필수다. |
| 2026-08-12 | D-002 | 현행 API를 우선하되 기능 완전 일치에 필요한 서버 변경은 허용한다. | 사용자 확정 | 기존 웹 호환성을 유지하는 최소 변경으로 구현한다. |
| 2026-08-12 | D-003 | 현행 모바일 UI/UX를 기준선으로 하고 네이티브 이점이 분명한 항목만 채택한다. | 사용자 요구 | UI 감사와 네이티브 개선 후보 평가가 필요하다. |
| 2026-08-12 | D-004 | 메인 에이전트는 구현하지 않고 서브에이전트 작업을 설계·조정한다. | 사용자 요구 | 모든 구현 작업은 명시적으로 배정한다. |
| 2026-08-12 | D-005 | **확정:** SwiftUI 네이티브 앱을 `ios/`에 구성한다. | 사용자 확정 | B1 프로젝트 기반 구현 진행 가능 |
| 2026-08-12 | D-006 | **확정:** 최소 iOS 17, Swift 6, iPhone 전용으로 시작한다. | 사용자 확정 | iPad 적응형 UI는 1차 범위에서 제외 |
| 2026-08-12 | D-007 | **확정:** B2에서 이메일 로그인·쿠키 세션을 먼저 고정하고 B3에서 소셜 로그인을 연결한다. | 사용자 확정 범위와 기술 의존성 | 최종 범위에는 Kakao/Naver 로그인이 포함됨 |
| 2026-08-12 | D-008 | **확정:** Dutypark 브랜드와 iOS 관례를 결합한 브랜드 하이브리드 UI를 채택한다. | 사용자 최초 요구와 플랫폼 결정 | 디자인 토큰과 네이티브 컴포넌트 매핑 필요 |
| 2026-08-12 | D-009 | **확정:** 관리자 기능을 제외한 일반 사용자 웹 기능 완전 일치를 목표로 한다. | 사용자 확정 | B4 기능 매트릭스의 완료 기준이며 관리자는 웹 전용 |
| 2026-08-12 | D-010 | **확정:** Kakao/Naver 로그인을 앱에 포함한다. | 사용자 확정 | B3 서버·앱 OAuth 변경이 필수 범위로 전환 |
| 2026-08-12 | D-011 | **확정:** 오프라인 기능은 후순위로 둔다. | 사용자 확정 | 1차는 온라인 오류·재시도 처리까지만 필수 |
| 2026-08-12 | D-012 | **확정:** 내부 빌드·시뮬레이터 검증 후 App Store 제출 준비 상태까지 진행한다. | 사용자 확정 | TestFlight/App Store 실제 배포 순서는 결정 대기 |
| 2026-08-12 | D-013 | **최우선 확정:** 웹과 iOS를 병행 운영하며 기존 웹 사이드이펙트 가능성이 있는 변경은 중단 후 사용자 승인을 받는다. | 사용자 확정 | 기존 계약 불변, iOS additive 경로, 모든 백엔드 공유 변경의 웹 회귀 테스트가 필수 |
| 2026-08-12 | D-014 | **사용자 승인:** 모바일 OAuth는 확인된 transaction 내부 provider HTTP 문제만 기존 `stateConsumedAt` 기반 짧은 claim/finalize transaction으로 수정한다. | 웹 안전을 지키면서 변경을 최소화 | 새 상태·credential·rate-limit infra/env·FK cascade 등은 현재 제외; 기존 웹 계약 불변 |
| 2026-08-12 | D-015 | **최우선 확정:** 현재 웹 수준 이상의 불필요한 방어·추상화·환경변수·상태를 선제 추가하지 않는다. | 사용자 구현 원칙 | 실제 요구나 재현 문제가 있을 때만 가장 작고 단순한 변경을 도입 |
| 2026-08-12 | D-016 | **구현 완료:** 모바일 OAuth 서버 기반은 승인된 최소 TX 경계만 수정하고 34/34 회귀 검증을 통과했다. | D-014, D-015 | 서버 기반은 완료; iOS OAuth 클라이언트 연결은 B2 이후 후속 |
| 2026-08-12 | D-017 | **구현 완료:** APNs는 기존 VAPID Web Push를 유지하고 `/api/auth/push/apns/register`, `/unregister`와 별도 installation·sender를 additive로 추가한다. | 웹/PWA 병행 운영과 최소 변경 원칙 | 실제 APNs 자격증명·실기기 E2E 전에는 B5를 완료 처리하지 않는다. |
| 2026-08-12 | D-018 | **진행 기준:** 기능별 SwiftUI 코드 존재와 기능 동등성 완료를 구분한다. | 최신 감사에서 대부분 구현됐지만 일부 런타임·권한·동등성 갭과 실기기 미검증이 확인됨 | §12 체크는 clean QA와 웹 교차 검증까지 끝난 행만 완료 처리한다. |

## 9. 사용자 질문 / 리스크

### 사용자 결정이 필요한 질문 — 우선순위 순

1. [ ] **P0:** APNs installation을 현재 refresh session에 귀속하도록 백엔드를 보정할지 결정 — 기존 웹/PWA refresh-token/푸시 계약 영향·additive 대안·회귀 검증안을 확인한 뒤 승인 전에는 구현하지 않는다.
2. [ ] AASA 제공과 첨부 10MB/50MB 노출 정책을 결정 — 둘 다 웹/운영 배포에 영향을 줄 수 있어 앱에서 임의 변경하지 않는다.
3. [ ] 내부 빌드 이후 **TestFlight 배포 → App Store 제출** 순서로 갈지, App Store 제출 준비만 완료한 뒤 배포 시점을 별도로 잡을지 결정
4. [ ] 공개 App Store 배포 전에 **Sign in with Apple**을 함께 구현할지 결정 — Kakao/Naver 제공에 따른 심사 요건 확인 후 통과해야 하는 사용자 결정 게이트

### 확정되어 닫힌 질문

- [x] `ios/`의 SwiftUI 네이티브 앱
- [x] 최소 iOS 17, Swift 6, iPhone 전용
- [x] Kakao/Naver 로그인 포함
- [x] 관리자 기능은 웹 전용
- [x] 오프라인 기능은 후순위
- [x] 관리자 제외 일반 사용자 웹 기능 완전 일치
- [x] B3는 기존 `stateConsumedAt`을 재사용한 짧은 claim/finalize transaction 최소 수정

### 현재 리스크

| ID | 리스크 | 영향 | 대응 방향 | 상태 |
|---|---|---|---|---|
| R-001 | HttpOnly 쿠키 중심 인증은 코드·단위 테스트가 구현됐으나 실제 운영 서버/기기 세션 복원 E2E가 없음 | 로그인/갱신 실패 가능 | 실제 iPhone에서 로그인·refresh·재실행 복원을 검증 | 런타임 검증 대기 |
| R-002 | Kakao/Naver PKCE 앱 클라이언트는 구현됐으나 provider console·실기기 E2E가 없음 | 로그인·연결·신규가입 실패 가능 | 운영 callback 등록 후 기존·신규·취소·실패를 실제 기기 검증 | 외부 준비 대기 |
| R-003 | APNs 등록·발송·수신 코드는 구현됐으나 자격증명·서명·실기기 검증이 없음 | 푸시 미수신 가능 | Apple 준비물을 연결하고 sandbox/production 실제 발송 확인 | 외부 준비 대기 |
| R-004 | 앱과 웹의 알림 읽음 상태·배지는 서버 단일 원천으로 구현됐으나 교차 앱 E2E가 없음 | 사용자 혼란 | 실제 APNs/PWA에서 동일 알림 읽음·배지 동기화 검증 | 통합 검증 대기 |
| R-005 | 실제 브라우저 모바일 검증을 수행하지 못함 | 정적 분석과 실제 UX 차이 가능 | 서버 실행 가능 시 13 mini/16 Pro 뷰포트로 재검증 | 검증 대기 |
| R-006 | 첨부 편집의 `orderedAttachmentIds`·HEIC→JPEG·앱 10MB 제한은 구현됐으나 웹 50MB 표시와 운영 proxy 제한은 미확정 | 데이터 손실 또는 업로드 실패 | 기존 ID 보존 계약 테스트를 유지하고 운영 한도 확인 전 공통 서버/웹 표시는 바꾸지 않음 | 앱 반영 / 운영 확인 필요 |
| R-007 | 로컬 날짜 직렬화 코드·테스트는 있으나 일정 검색 DTO의 웹/서버 불일치가 남음 | 검색 실패 또는 시간 오해 | 실제 응답 fixture와 웹 동작을 확인하고 공통 DTO 변경이 필요하면 사용자 승인 | 부분 반영 / 계약 확인 필요 |
| R-008 | 모바일 OAuth `state`와 callback 검증 필요 | 로그인 CSRF·redirect 오용 위험 | 해시 state·PKCE와 고정 `dutypark://oauth/callback` 적용; 기존 웹 경로 불변 | 모바일 서버 해결 |
| R-009 | 앱 내 계정 삭제 기능이 없음 | App Store 심사 차단 가능 | B5에서 삭제 API·확인 화면·데이터 처리 정책 구현 | B5 필수 |
| R-010 | 제3자 로그인 제공 시 Sign in with Apple 요건 적용 가능성이 높음 | App Store 심사 차단 가능 | Apple 로그인 동시 제공을 출시 범위에 포함할지 결정 | 사용자 결정 필요 |
| R-011 | 개인정보 처리방침이 실제 쿠키 인증과 불일치함 | 사용자 고지·심사 리스크 | 실제 저장·전송 방식을 기준으로 정책 수정 | App Store 전 필수 |
| R-012 | UGC 신고·차단·운영 절차가 앱 심사 요건에 부족할 수 있음 | 심사 또는 운영 리스크 | 노출 기능 범위와 신고·차단 기능 점검 | 검토 필요 |
| R-013 | iOS-only `main` 병합도 현 CI에서 서버 재배포를 유발함 | 불필요한 배포와 운영 위험 | 별도 `ios.yml`, 경로 필터, 배포 조건 도입 검토 | CI 변경 논의 필요 |
| R-014 | iOS 지원을 위해 공유 인증·API·알림 계약을 변경하면 운영 중인 웹/PWA가 회귀할 수 있음 | 로그인·데이터·OAuth·Web Push 장애 | 기본은 iOS 전용 additive 경로; 영향 가능 시 작업 중단 후 영향·대안·회귀안 승인 | 상시 승인 게이트 |
| R-015 | class-level `@Transactional`과 row lock 동안 provider HTTP를 호출함 | DB pool 최대 5개가 고갈돼 기존 웹 요청까지 장애 가능 | 기존 `stateConsumedAt` claim → transaction 밖 HTTP → 짧은 finalize transaction 적용 | 해결·34/34 통과 |
| R-016 | 인증 없는 모바일 authorize의 DB row 발급은 리뷰 우려이나 현재 운영 문제로 확인되지 않음 | 과도한 선제 대응 시 불필요한 인프라·설정 증가 | custom rate limit·발급 상한은 현재 추가하지 않고 실제 증거가 생기면 재평가 | 현재 범위 제외 |
| R-017 | 백엔드 회귀 범위 1,065개 중 1,044 성공·기존 21 skip·기능 assertion 실패 0이나 단일 프로세스 말미 OOM이 관찰됨 | 단일 실행의 종료 코드 green 증거는 제한됨 | OOM이 난 팀 관리 suite는 새 JVM 19/19 성공; 기능 회귀 없음으로 기록하되 자원 안정화와 분리 실행을 유지 | 기능 회귀 없음 / 실행 자원 주의 |
| R-018 | 표준 `docker-compose.yml`의 APNs 자격증명 3개 전달이 필요했음 | 값을 준비해도 APNs가 무음 no-op 가능 | 기존 3개 설정만 compose에 최소 연결함; 실제 자격증명 발송 smoke test는 별도 | 연결 완료 / 외부 E2E 대기 |
| R-019 | Personal Team local-only device build는 성공했지만 연결 가능한 iPhone과 배포용 유료 Team/provisioning, Kakao/Naver callback·APNs key가 없음 | 실기기 설치·OAuth/APNs E2E 차단 | §0 외부 준비 게이트를 완료하고 저장소에는 secret을 넣지 않음 | 설치·외부 준비 대기 |
| R-020 | 5개 locale 카탈로그 724키는 누락이 없지만 일부 화면이 명시적 locale 없이 문자열을 선계산함 | 앱 내 언어 선택이 즉시 반영되지 않을 수 있음 | 최근 수정분의 런타임 전환을 5개 언어에서 최종 검증 | 진행 중 |
| R-021 | 2차 감사의 세션/OAuth/Push preference/Social sync/Settings deeplink·toolbar/Profile sync/첨부 discard·safety P1 | 웹 동등성 미달 또는 상태 불일치 가능 | 최소 보정과 targeted test를 완료하고 freeze3 최종 QA에서 재확인 | 보정 완료 / 재감사 중 |
| R-022 | Calendar·Team·Guide·공개 링크 share/deeplink P1은 보정됐으나 운영 AASA가 `text/html` SPA fallback이고 업로드 10/50MB 정책이 미확정 | Universal Link와 업로드 사용자 경험 미확정 | 앱 보정·targeted test는 완료. AASA/업로드 공통 변경은 웹·배포 영향이 있어 사용자 협의 전 수행하지 않음 | 앱 보정 완료 / 협의 게이트 |
| R-023 | APNs installation이 현재 refresh session에 명시적으로 귀속되지 않는 P0 | 로그아웃·세션 종료 뒤 기기 푸시 귀속이 웹 세션 의미와 어긋날 수 있음 | 최소 변경안과 additive 대안, 기존 Web Push·refresh 회귀안을 사용자에게 제시; 승인 전 구현 금지 | 승인 대기 |

## 10. 검증 항목

### 기능 검증

- [ ] 이메일 로그인, 로그아웃, 토큰 갱신, 세션 만료
- [ ] Kakao/Naver OAuth 및 취소·실패 복구
- [ ] 일정 조회, 생성, 수정, 삭제, 시간 파싱 상태 갱신
- [ ] 친구 요청, 승인, 거절, 차단 및 권한 기반 가시성
- [ ] 팀 생성·참여·관리자 기능과 일정 공유
- [ ] 할 일 생성·수정·완료·삭제
- [ ] 실제 웹 범위인 `SCHEDULE`, `TODO` 첨부와 별도 프로필 사진 API
- [ ] 알림 조회, 읽음 처리, 배지, 딥 링크
- [ ] 보조 계정과 가장 기능

### 품질 검증

- [ ] iPhone 16 Pro 및 iPhone 13 mini 기준 레이아웃
- [ ] 라이트/다크 모드와 시스템 글자 크기
- [ ] VoiceOver, Reduce Motion, 대비, 44pt 이상 터치 영역
- [ ] 한국어, English, 日本語, 简体中文, Español 문구 정합성
- [ ] 느린 네트워크, 오프라인, 서버 오류, 재시도
- [ ] 앱 백그라운드/포그라운드 전환과 메모리 경고
- [ ] 민감정보의 키체인 저장, 로그 마스킹, ATS 적용
- [ ] 웹/PWA 회귀 없음

### 웹 병행 운영 회귀 게이트

- [ ] 기존 endpoint 경로, 요청·응답 DTO, 오류 code의 하위 호환성
- [ ] 기존 access/refresh HttpOnly 쿠키 속성·수명·갱신·삭제 동작
- [ ] 기존 웹 이메일 로그인·refresh·로그아웃
- [ ] 기존 웹 Kakao/Naver OAuth callback과 성공·취소·실패 동작
- [ ] PWA 설치·서비스 워커·인앱 알림 폴링
- [ ] 기존 VAPID Web Push 구독·해제·발송·배지
- [x] 백엔드 공유 변경별 타깃 테스트와 웹 타입 검사·빌드·관련 테스트
- [ ] 사이드이펙트 가능 변경의 영향 범위·대안·회귀 검증안에 대한 사용자 사전 승인

### 우선 검증 순서

1. [ ] **현재 작업:** freeze2 전체 105/105 성공 이후 freeze3 최종 clean QA와 마지막 기능 동등성 감사를 완료한다.
2. [ ] fixture 기반 contract test와 실제 서버 교차 검증: 일정 검색 DTO, 첨부 순서, 오류 코드, 날짜·시간 직렬화
3. [ ] iPhone 13 mini와 iPhone 16 Pro 화면·상호작용 검증
4. [ ] 5개 언어 런타임 전환, 라이트/다크 모드, Dynamic Type, VoiceOver 검증
5. [ ] 연결 가능한 실제 iPhone에서 Personal Team 빌드를 설치하고 cookie 세션·기본 기능을 검증한 뒤, 유료 Team/provider/APNs 준비 후 OAuth·APNs E2E를 검증

B2 구현 원칙:

- 현재 로그인·refresh·로그아웃에 필요한 `URLSession` 코드만 만든다.
- 실제 중복이나 교체 요구가 생기기 전에는 protocol 계층, 범용 repository, DI container, router 같은 기반 추상화를 추가하지 않는다.
- 기존 HttpOnly 쿠키 계약을 그대로 사용하고 서버 변경 없이 cookie POC를 먼저 통과시킨다.

### 빌드·테스트 명령

- iOS build: `cd ios && xcodebuild -project Dutypark.xcodeproj -scheme Dutypark -destination 'generic/platform=iOS Simulator' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build-for-testing`
- iOS test: `cd ios && xcodebuild -project Dutypark.xcodeproj -scheme Dutypark -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build CODE_SIGNING_ALLOWED=NO test`
- Backend: `./gradlew test` 또는 변경 범위의 타깃 테스트
- Frontend: `cd frontend && npm run type-check && npm run build`
- Frontend tests: `cd frontend && npm run test`

## 11. 다음 조정 회의 체크포인트

- [x] 병렬 조사 결과를 하나의 기능/API/화면 기준선으로 통합한다.
- [x] 서버 무변경으로 가능한 MVP 경계를 제시한다.
- [x] 서버 변경 후보는 필요성·규모·호환성·대안을 나란히 제시한다.
- [x] 사용자에게 기술 방식과 1차 제품 범위의 결정을 받는다.
- [x] 결정 후 충돌 없는 B1~B5 실행 배치로 나누어 작업표를 갱신한다.
- [x] B1 담당 에이전트를 배정하고 `ios/` 프로젝트 골격과 테스트 타깃을 구현한다.
- [x] B1의 짧은 탭·화면 title 5개 언어 분리와 실제 5탭 이동 UI test를 추가한다.
- [x] B2 공통 `APIClient`와 이메일 cookie POC 담당을 배정하고 구현한다.
- [x] B3 transaction 경계 최소 수정안에 대한 사용자 승인을 기록한다.
- [x] B3 서버를 `stateConsumedAt` claim, transaction 밖 HTTP, 짧은 finalize transaction으로 최소 수정하고 mobile+web OAuth 34/34를 검증한다.
- [x] B3 iOS OAuth 클라이언트 연결을 배정하고 구현한다.
- [x] B4 기능별 구현과 B5 APNs 서버·앱 구현을 병렬 배정하고 통합한다.
- [x] freeze2 최신 iOS 전체 105/105를 통과한다.
- [x] 2차 감사의 P1 세션/OAuth/Push preference/Social sync/Calendar/Team/Settings Guide/deeplink/share/toolbar/Profile sync/attachment safety/discard guard를 보정하고 targeted test를 통과한다.
- [x] final nits·Todo attachment/discard·core parity를 보정하고 Calendar 17/17 등 targeted test를 통과한다.
- [ ] freeze3 최종 clean QA와 마지막 기능 동등성 감사를 완료한다.
- [ ] APNs refresh-session 귀속 P0의 웹 영향·대안·회귀안을 제시하고 사용자 승인을 받는다.
- [x] Personal Team local-only device app build를 성공시킨다.
- [ ] 연결 가능한 iPhone에 설치해 실제 실행을 확인한다.
- [ ] Apple/Kakao/Naver 외부 준비 후 실제 iPhone 설치·OAuth·APNs E2E를 완료한다.

## 12. 기능 동등성 매트릭스

### 12.1 범위와 공통 완료 기준

이 표는 현재 웹/PWA에서 실제로 제공하는 일반 사용자 기능을 iOS에서 빠짐없이 재현하기 위한 완료 계약이다. **서비스 관리자 화면(`/admin`, `/admin/teams`, `/admin/dev`)과 오프라인 동기화는 제외**한다. 팀 대표 관리자·팀 매니저가 사용하는 `/team/manage/:teamId`는 서비스 관리자 기능이 아니므로 포함한다.

> 구현 코드와 targeted test가 대부분 존재하지만 공통 완료 기준의 실제 서버·웹 교차 검증이 끝나지 않았으므로 기능 행은 일괄 완료 처리하지 않는다. freeze2 전체 105/105와 final nits·Todo 첨부·core parity targeted test는 완료했다. 현재 freeze3 최종 QA, 실제 iPhone 설치, APNs refresh-session 귀속 P0 승인, API `code`별 5개 언어 표시·런타임 언어/접근성 확인, AASA와 10/50MB 정책 협의가 남아 있다.

담당 표기:

- `B2 인증·세션`: 공통 APIClient, 쿠키 세션, 이메일 인증
- `B3-IOS OAuth`: Kakao/Naver 로그인·연결·신규 SSO 가입
- `B4-A 홈·캘린더`: 앱 셸, 홈, 달력 공통 탐색, 공개 캘린더
- `B4-B 근무·일정`: 근무, 근무 패턴, 개인 일정, 검색, D-Day
- `B4-C Todo`: Todo 보드와 달력 내 Todo
- `B4-D 관계·팀`: 친구·가족, 개인 관리 위임, 팀, 팀 관리
- `B4-E 알림`: 인앱 알림, 배지, 알림 목적지 이동
- `B4-F 첨부`: 일정·Todo 첨부와 프로필 사진
- `B4-G 설정·공개`: 프로필, 정책·가이드, 언어·테마, 공개 진입점
- `B5 Push`: APNs 등록·해제·발송과 기존 Web Push 회귀 검증

모든 행은 다음 조건을 함께 만족해야 완료다.

- [ ] 서버의 소유권·캘린더 공개범위·일정 공개범위·가족·개인 관리 위임·팀 권한 판정을 앱에서 완화하지 않는다.
- [ ] 쓰기 후 서버 재조회와 웹 재접속에서 결과가 같고, 웹에서 변경 후 앱 재조회에도 같은 결과가 보인다.
- [ ] 인증 필요 화면은 로그인 후 원래 목적지로 복귀하고, `401`은 기존 계약대로 refresh를 한 번 수행한 뒤 원요청을 한 번만 재시도한다.
- [ ] 각 사용자 화면에 웹과 같은 로딩·빈 상태·서버 오류 처리가 있고 API의 machine-readable `code`를 5개 언어 문구로 표시한다.
- [ ] 한국어, English, 日本語, 简体中文, Español 및 라이트·다크 모드에서 확인한다.
- [ ] 웹에 없는 기능, 서버에만 있고 웹 UI에서 쓰지 않는 endpoint, 미래용 설정·추상화는 추가하지 않는다.

### 12.2 인증·OAuth·세션

| 완료 | 웹 기능 | Endpoint / 계약 | iOS feature owner | 완료 조건 |
|---|---|---|---|---|
| [ ] | 앱 시작 세션 판정·복원 | `GET /api/auth/status` → 필요 시 `POST /api/auth/refresh` → status | B2 인증·세션 | 유효 세션, access 만료+refresh 성공, refresh 만료, 서버 오류를 구분하고 앱 재실행 후 HttpOnly 쿠키 세션이 복원된다. |
| [ ] | 이메일 로그인·원래 목적지 복귀 | `POST /api/auth/token`; 로그인 입력은 이메일·비밀번호 | B2 인증·세션 | 로그인 성공 시 cookie 저장 후 status를 읽고, 실패 `code`를 표시하며 보호 화면에서 온 사용자는 원래 화면으로 돌아간다. |
| [ ] | 로그아웃 | `POST /api/auth/logout` | B2 인증·세션 | 서버 쿠키와 앱 인증 상태가 지워지고 공개/로그인 화면으로 안전하게 돌아간다. |
| [ ] | 비밀번호 변경 | `PUT /api/auth/password` | B2 인증·세션, B4-G 설정·공개 | 웹과 같은 현재 비밀번호·새 비밀번호 검증(새 비밀번호 8~20자)을 적용하고 성공 후 재로그인한다. |
| [ ] | 로그인 기기·세션 목록 | `GET /api/auth/refresh-tokens?validOnly=true` | B2 인증·세션, B4-G 설정·공개 | 현재 세션을 구분해 OS·기기·IP·사용/만료 시각을 웹 수준으로 표시한다. |
| [ ] | 특정/다른 모든 세션 종료 | `DELETE /api/auth/refresh-tokens/{id}`, `DELETE /api/auth/refresh-tokens/others` | B2 인증·세션, B4-G 설정·공개 | 지정 세션 또는 현재 기기 외 세션이 종료되고 목록과 현재 로그인 상태가 정확히 갱신된다. |
| [ ] | Kakao/Naver 로그인 시작·복귀·교환 | `POST /api/auth/mobile/oauth/authorize`(`LOGIN`, PKCE S256) → `ASWebAuthenticationSession` → `dutypark://oauth/callback` → `POST /api/auth/mobile/oauth/exchange` | B3-IOS OAuth | 두 provider 모두 기존 사용자 성공, 취소, provider 실패, state/code 만료, code 1회 사용을 처리하고 exchange 응답의 기존 HttpOnly cookie로 세션을 연다. |
| [ ] | Kakao/Naver 신규 SSO 가입 | exchange의 `signupRequired/signupUuid`; `GET /api/policies/current`; `POST /api/auth/sso/signup/token` | B3-IOS OAuth, B4-G 설정·공개 | 이름 1~10자, 최신 약관·개인정보 전문과 필수 동의·버전을 제출하고 가입 후 원래 목적지로 이동한다. |
| [ ] | Kakao/Naver 계정 연결 | `POST /api/auth/mobile/oauth/authorize`(`LINK`)과 provider callback | B3-IOS OAuth, B4-G 설정·공개 | `/members/me`의 연결 상태를 표시하고 미연결 provider만 연결하며 성공·취소·`already_linked` 오류를 웹과 같이 처리한다. 연결 해제 기능은 웹에 없으므로 만들지 않는다. |
| [ ] | 보조 계정 생성·목록 | `POST /api/members/auxiliary`(이름 1~10자), `GET /api/members/managed` | B4-D 관계·팀 | 이메일/비밀번호 없는 보조 계정을 만들고 관리 대상 목록에 즉시 반영한다. |
| [ ] | 관리 대상 계정 전환·원계정 복귀 | `POST /api/auth/impersonate/{targetMemberId}`, `POST /api/auth/restore` | B2 인증·세션, B4-D 관계·팀 | manager인 대상만 전환하고 impersonation 표시·남은 시간·수동 복귀·만료 시 자동 복귀를 제공한다. 복귀 실패 시 로그인으로 이동한다. |

### 12.3 홈·개인 캘린더·근무·일정

| 완료 | 웹 기능 | Endpoint / 계약 | iOS feature owner | 완료 조건 |
|---|---|---|---|---|
| [ ] | 비로그인 홈 | `/`의 소개 콘텐츠; `/auth/login`, `/guide`, `/terms`, `/privacy` 진입 | B4-A 홈·캘린더, B4-G 설정·공개 | 로그인하지 않은 사용자가 웹의 소개·로그인·가이드·정책 진입점을 사용할 수 있다. PWA 설치 안내는 네이티브 앱에 만들지 않는다. |
| [ ] | 로그인 홈의 내 오늘 정보 | `GET /api/dashboard/my` | B4-A 홈·캘린더 | 오늘 날짜, 내 근무, 오늘 일정을 웹과 같은 정보 우선순위와 빈 상태로 표시하고 내 캘린더로 이동한다. |
| [ ] | 로그인 홈의 친구 오늘 정보 | `GET /api/dashboard/friends` | B4-A 홈·캘린더 | 친구별 오늘 근무·허용된 일정·관계 요청을 표시하고 친구 캘린더 이동, 친구 검색·요청, pin/unpin·순서 변경이 친구 화면과 동기화된다. |
| [ ] | 개인/친구/공개 캘린더 진입 | `/duty/{memberId}`; `GET /api/members/{memberId}`, `/api/calendar`, `/api/holidays` | B4-A 홈·캘린더 | 비회원 PUBLIC, 로그인 관계별 PUBLIC/FRIENDS/FAMILY/PRIVATE 및 개인 관리 위임 판정이 웹·서버와 같고 권한이 없으면 편집 UI를 보이지 않는다. |
| [ ] | 월 달력 공통 탐색 | `GET /api/calendar?year&month`, `GET /api/holidays?year&month` | B4-A 홈·캘린더 | 이전/다음 달, 오늘, 연월 선택, 날짜 상세, 공휴일, 검색·알림 목적 날짜 강조가 월 경계에서도 정확하다. |
| [ ] | 월간 근무 조회·집계 | `GET /api/duty?memberId&year&month`, `GET /api/teams/{teamId}` | B4-B 근무·일정 | 근무 색·유형·출처와 유형별 집계, 선택일 상세가 보이며 공개범위와 같은 팀 조회 규칙은 서버 결과를 그대로 따른다. |
| [ ] | 하루 근무 변경·빠른 연속 입력·셀 배치 편집 | `PUT /api/duty/change`; 편집 권한 확인 `GET /api/members/{memberId}/canManage` | B4-B 근무·일정 | 현재 웹 UI와 동일하게 본인 또는 개인 위임 manager에게만 편집을 제공하고 저장 결과를 즉시 달력에 반영한다. 서버가 더 넓게 허용하더라도 앱 UI 범위를 넓히지 않는다. |
| [ ] | 월 전체 같은 근무 적용 | `PUT /api/duty/batch` | B4-B 근무·일정 | 웹과 같이 본인 캘린더에서만 확인 후 적용하고 성공·실패 뒤 서버 상태를 재조회한다. |
| [ ] | 개인 근무표 Excel 업로드 | `POST /api/duty_batch` multipart | B4-B 근무·일정 | 웹과 같이 본인 및 팀 batch template이 있는 경우에만 파일을 선택하고 결과의 성공·건너뜀·오류 요약을 표시한다. |
| [ ] | 친구 근무 같이 보기 | `GET /api/duty/others?memberIds&year&month`, `GET /api/friends` | B4-B 근무·일정 | 내 캘린더에서는 친구 최대 3명, 타인 캘린더에서는 내 근무 토글을 지원하고 선택 해제·월 이동 후 overlay가 정확하다. |
| [ ] | 근무 패턴 조회·등록·수정·삭제 | `GET/PUT/DELETE /api/duty/pattern/me` | B4-B 근무·일정, B4-G 설정·공개 | 요일별 근무 유형, 미선택 요일 OFF, 공휴일 OFF, 적용 시작월과 hidden duty type의 paused 상태를 표시한다. 팀/유형이 없으면 웹과 같은 안내만 제공한다. |
| [ ] | 월간 개인 일정 조회·날짜 상세 | `GET /api/schedules?memberId&year&month` | B4-B 근무·일정 | 다일 일정, 시간, 소유자·태그, 설명, 공개범위, 첨부 유무와 날짜 내 순서를 권한 범위 안에서 표시한다. |
| [ ] | 일정 생성·수정 | `POST /api/schedules`(id 유무로 생성/수정) | B4-B 근무·일정 | 제목 최대 50자, 설명, 시작·종료 일시, PUBLIC/FRIENDS/FAMILY/PRIVATE, 친구 태그, 첨부를 저장한다. 소유자 또는 개인 위임 manager만 편집하고 기존 비동기 시간 파싱 계약을 변경하지 않는다. |
| [ ] | 일정 삭제·정렬 | `DELETE /api/schedules/{id}`, `PATCH /api/schedules/positions` | B4-B 근무·일정 | 소유 일정만 삭제·같은 날짜 안에서 정렬하며 재조회·웹 접속 후 순서가 유지된다. |
| [ ] | 일정 태그 관리 | `POST/DELETE /api/schedules/{scheduleId}/tags/{friendId}`, `DELETE /api/schedules/{scheduleId}/tags` | B4-B 근무·일정 | 소유자는 자신의 친구를 추가·해제하고, 태그된 사용자는 읽기와 자기 태그 해제만 가능하다. |
| [ ] | 일정 검색 | `GET /api/schedules/{memberId}/search?q&page&size` | B4-B 근무·일정 | 본인 또는 개인 위임 manager만 검색하고 10개 단위 페이지, 결과 날짜의 달력 이동·강조를 제공한다. 아래 12.9의 DTO 불일치를 먼저 해결하거나 계약을 확정한다. |
| [ ] | D-Day 조회·고정 | `GET /api/dday`, `GET /api/dday/{memberId}`; 고정값은 앱 로컬 저장 | B4-B 근무·일정 | 날짜순과 D-Day/D±N을 표시하고 타인 D-Day는 private을 제외한다. 하나의 고정 선택이 사용자·대상별로 앱 재실행 후 유지된다. |
| [ ] | D-Day 생성·수정·삭제 | `POST /api/dday`(id 유무), `DELETE /api/dday/{id}` | B4-B 근무·일정 | 본인만 제목 1~30자, 날짜, 비공개 여부를 CRUD하고 웹의 오늘·±1일·±7일 빠른 조정을 제공한다. |

### 12.4 Todo와 첨부

| 완료 | 웹 기능 | Endpoint / 계약 | iOS feature owner | 완료 조건 |
|---|---|---|---|---|
| [ ] | 3상태 Todo 보드 | `GET /api/todos/board` | B4-C Todo | TODO/IN_PROGRESS/DONE 목록·건수·태그 소유자를 웹 모바일 탭과 같은 정보 구조로 표시한다. |
| [ ] | Todo 생성·수정·삭제 | `POST /api/todos`, `PUT/DELETE /api/todos/{id}` | B4-C Todo | 제목·내용·마감일·상태·친구 태그·첨부를 저장하고 소유자만 내용·태그·첨부 편집과 삭제를 할 수 있다. |
| [ ] | Todo 완료·재개·상태 변경 | `PATCH /api/todos/{id}/complete`, `/reopen`, `/status` | B4-C Todo | 소유자 또는 태그된 사용자가 허용된 상태 변경을 하고 보드와 개인 달력의 표시가 함께 갱신된다. |
| [ ] | Todo 순서 변경 | `PATCH /api/todos/positions` | B4-C Todo | 열 안/열 사이 이동 후 상태와 순서가 유지되며 태그된 사용자의 `TodoTag.tagOrder`가 소유자 순서와 혼동되지 않는다. 드래그 외 상태 변경 대안도 제공한다. |
| [ ] | Todo 태그 해제 | `DELETE /api/todos/{id}/tags`; 저장 DTO의 `tagFriendIds` 동기화 | B4-C Todo | 태그된 사용자가 자기 태그를 해제하고, 소유자는 편집 저장으로 친구 태그를 관리한다. 웹 UI가 직접 쓰지 않는 별도 tag endpoint를 위한 추가 화면은 만들지 않는다. |
| [ ] | 개인 달력 내 Todo | `GET /api/todos/board`와 위 Todo 쓰기 endpoint | B4-B 근무·일정, B4-C Todo | 기본 IN_PROGRESS와 웹의 TODO 표시 필터, due-date bubble, 상세·수정·완료·재개가 보드와 같은 데이터·권한을 사용한다. |
| [ ] | 첨부 세션·업로드 | `POST /api/attachments/sessions`; `POST /api/attachments` multipart(`sessionId`,`file`); `DELETE /sessions/{sessionId}` | B4-F 첨부 | **실제 웹 사용 범위인 SCHEDULE·TODO만** 다중 선택·업로드 진행·취소를 지원한다. enum에만 있는 TEAM/PROFILE 첨부 UI는 일반화하지 않는다. |
| [ ] | 첨부 저장 동기화·순서·제거 | 일정/Todo 저장의 `attachmentSessionId`, `orderedAttachmentIds`; `POST /api/attachments/reorder`, `DELETE /api/attachments/{id}` | B4-F 첨부 | 편집 저장 때 기존 ID를 항상 명시해 의도하지 않은 전체 삭제를 막고 제거·정렬 결과가 재조회 후 유지된다. |
| [ ] | 첨부 목록·미리보기·다운로드 | `GET /api/attachments?contextType&contextId`, `GET /{id}/thumbnail`, `GET /{id}/download?inline=true` | B4-F 첨부 | 공개 일정은 익명 read gate, Todo는 owner/tagged read gate를 따르며 이미지 미리보기와 파일 열기·공유가 cookie 포함 요청으로 동작한다. 웹과 같은 50MB 표시와 실제 서버/운영 제한 불일치는 12.9 게이트에서 확정한다. |

### 12.5 친구·가족·팀·팀 관리

| 완료 | 웹 기능 | Endpoint / 계약 | iOS feature owner | 완료 조건 |
|---|---|---|---|---|
| [ ] | 친구·가족 현황과 요청함 | `GET /api/dashboard/friends`, `GET /api/notifications/friend-request-count` | B4-D 관계·팀 | 친구 목록, 오늘 정보, 받은/보낸 친구·가족 요청과 배지 수가 일치한다. |
| [ ] | 친구 검색·요청·취소·수락·거절 | `GET /api/friends/search`; `POST /request/send/{id}`, `/request/accept/{id}`, `/request/reject/{id}`; `DELETE /request/cancel/{id}` | B4-D 관계·팀 | 페이지 검색과 모든 요청 상태가 처리 직후 홈·친구·알림 수에 반영되고 서버의 중복/자기 요청 오류를 표시한다. |
| [ ] | 가족 요청·일반 친구 전환·친구 삭제 | `PUT /api/friends/family/{id}`, `DELETE /api/friends/family/{id}`, `DELETE /api/friends/{id}` | B4-D 관계·팀 | 기존 친구만 가족 요청을 보내고 수락 흐름, 양방향 일반 친구 전환·삭제 결과가 웹과 같다. |
| [ ] | 친구 고정·순서·캘린더 이동 | `PATCH /api/friends/pin/{id}`, `/unpin/{id}`, `/pin/order` | B4-D 관계·팀 | 홈과 친구 화면의 고정 상태·순서가 같고 카드를 누르면 해당 `/duty/{memberId}` 캘린더로 이동한다. |
| [ ] | 개인 관리 권한 위임·해제 | `GET /api/members/family`, `/managers`; `POST/DELETE /api/members/manager/{managerId}` | B4-D 관계·팀 | 웹과 같이 가족만 후보로 보여 위임·해제하고 대상 캘린더의 편집 가능 여부가 즉시 바뀐다. 서버 API의 더 넓은 후보 가능성을 앱 기능으로 노출하지 않는다. |
| [ ] | 내 팀 월 화면·팀 없음 상태 | `GET /api/teams/my?year&month`, `/api/calendar`, `/api/holidays`, `/api/duty` | B4-D 관계·팀 | 팀 없음과 팀 있음 상태, 월/연월/오늘 탐색, 내 근무색·공휴일·팀 일정이 웹과 같다. |
| [ ] | 날짜별 근무조와 멤버 이동 | `GET /api/teams/shift?year&month&day` | B4-D 관계·팀 | 근무유형별 멤버·인원, 내 그룹·본인 강조를 표시하고 허용된 멤버 캘린더로 이동한다. |
| [ ] | 팀 일정 조회·생성·수정·삭제 | `GET /api/teams/schedules`; `POST /api/teams/schedules`; `DELETE /api/teams/schedules/{id}` | B4-D 관계·팀 | 전원은 읽고 팀 manage 권한 사용자만 제목·설명·시작/종료일의 팀 일정을 CRUD한다. |
| [ ] | 팀 관리 상세·권한 게이트 | `GET /api/teams/manage/{teamId}` | B4-D 관계·팀 | 해당 팀 member만 읽고 대표 관리자·팀 매니저의 현재 서버 권한에 맞춰 각 액션을 노출한다. 서비스 관리자 전용 빈 팀 삭제는 제외한다. |
| [ ] | 팀 구성원 검색·추가·제거 | `GET /api/teams/manage/members`; `POST/DELETE /api/teams/manage/{teamId}/members` | B4-D 관계·팀 | 페이지 검색, 팀 없는 회원 추가, 제거 확인과 결과 갱신을 제공하며 제거 뒤 근무 패턴 종료 등 서버 결과를 그대로 반영한다. |
| [ ] | 팀 매니저·대표 관리자 변경 | `POST/DELETE /api/teams/manage/{teamId}/manager`; `PUT /api/teams/manage/{teamId}/admin` | B4-D 관계·팀 | 웹의 현재 노출 조건과 서버 허용/거절 결과를 그대로 처리한다. 아래 12.9의 웹 UI/서버 권한 불일치를 임의로 확대·수정하지 않는다. |
| [ ] | 근무 유형 관리 | `PATCH /default-duty`; `POST/PATCH /duty-types`; `PATCH /duty-types/swap-position`; `PATCH /duty-types/{id}/visibility` | B4-D 관계·팀 | 기본 OFF 이름·색, 추가 유형 생성·편집·순서·숨김/복원이 권한 있는 사용자에게만 보이고 저장 뒤 재조회와 일치한다. |
| [ ] | 팀 근무 batch template·Excel 업로드 | `GET /api/duty_batch/templates`; `PATCH /batch-template`; `POST /api/teams/manage/{teamId}/duty` multipart | B4-D 관계·팀 | template 선택과 현재~다음 연도 `.xlsx` 업로드 결과·오류를 웹 수준으로 표시한다. |

### 12.6 알림·Push

| 완료 | 웹 기능 | Endpoint / 계약 | iOS feature owner | 완료 조건 |
|---|---|---|---|---|
| [ ] | 알림 페이지·더 보기 | `GET /api/notifications?page&size`, `GET /api/notifications/unread`, `/count` | B4-E 알림 | 20개 단위 더 보기, 상대/절대 시각, 빈 상태, 전체·미읽음 수를 표시하고 foreground 복귀 시 갱신한다. |
| [ ] | 읽음·삭제 | `PATCH /api/notifications/{id}/read`, `/read-all`; `DELETE /api/notifications/{id}`, `/read` | B4-E 알림 | 개별/전체 읽음, 개별 삭제, 읽은 알림 전체 삭제 후 목록·탭/앱 badge가 같은 서버 상태를 반영한다. |
| [ ] | 알림 목적지 이동 | `FRIEND_REQUEST`→친구, `TODO`→Todo, `MEMBER`→`/duty/{id}`, `SCHEDULE`→`GET /api/schedules/{id}` 후 시작일 달력 | B4-E 알림, 각 화면 owner | 앱 실행 중과 알림 탭 진입에서 해당 탭·상세·날짜로 이동하며 알 수 없는 type/version은 안전한 알림 목록 fallback으로 처리한다. |
| [ ] | 인앱 알림 폴링·배지 | `/api/notifications/unread`, `/count`, `/friend-request-count` | B4-E 알림 | 웹의 표시 중 갱신·foreground 즉시 동기화 의미를 유지하고 실패 시 UI를 막지 않으며 서버 unread count를 badge 단일 원천으로 쓴다. |
| [ ] | 네이티브 푸시 권한·등록·해제 | `POST /api/auth/push/apns/register`, `/unregister`; 기존 `/api/auth/push/**`는 Web Push 전용 | B5 Push | 실제 iPhone에서 권한 허용·거절, token 갱신, 로그아웃/해제가 동작한다. 신규 APNs 경로는 기존 VAPID subscribe/unsubscribe 계약을 변경하지 않는다. |
| [ ] | APNs 수신·탭·배지 | 공통 Notification payload와 위 알림 endpoint | B5 Push, B4-E 알림 | foreground/background/종료 상태에서 수신·탭 이동·badge가 동작하고 같은 알림의 앱/웹 읽음 상태가 중복되지 않는다. 기존 PWA Web Push 회귀 테스트를 통과한다. |

### 12.7 프로필·설정·정책·가이드·공개 링크

| 완료 | 웹 기능 | Endpoint / 계약 | iOS feature owner | 완료 조건 |
|---|---|---|---|---|
| [ ] | 내 프로필 정보 | `GET /api/members/me` | B4-G 설정·공개 | 이름·팀·이메일·소셜 연결 상태·캘린더 공개범위를 웹과 같이 표시한다. |
| [ ] | 프로필 사진 변경·삭제·조회 | `PUT/DELETE /api/members/profile-photo`; `GET /api/members/{memberId}/profile-photo` | B4-F 첨부, B4-G 설정·공개 | 사진 선택·웹 수준 crop·업로드·삭제 후 profilePhotoVersion 재조회로 홈·친구·팀의 사진이 갱신된다. 일반 첨부 PROFILE context로 바꾸지 않는다. |
| [ ] | 캘린더 공개범위와 audience 미리보기 | `PUT /api/members/{memberId}/visibility`; `GET /api/friends` | B4-G 설정·공개 | PUBLIC/FRIENDS/FAMILY/PRIVATE 및 실제 친구·가족 열람 대상 미리보기를 제공하고 변경 즉시 공개 캘린더 조회에 반영한다. |
| [ ] | 언어 | 앱 번들 `ko/en/ja/zh/es`; 서버 endpoint 없음 | B4-G 설정·공개 | 기기 언어는 최초 표시/제안일 뿐이며 사용자가 명시적으로 선택한 뒤에만 저장한다. 언어명은 `한국어`, `English`, `日本語`, `简体中文`, `Español`로 표시한다. |
| [ ] | 테마 | 앱 로컬 `light/dark`; 서버 endpoint 없음 | B4-G 설정·공개 | 웹과 같은 명시적 라이트·다크 두 선택만 제공하고 재실행 후 유지한다. 웹에 없는 자동 테마 설정은 추가하지 않는다. |
| [ ] | 이용약관·개인정보처리방침 | `GET /api/policies/current`, `GET /api/policies/terms`, `/privacy` | B4-G 설정·공개 | 로그인 여부와 무관하게 서버의 최신 Markdown 전문·버전·시행일을 로딩/없음/오류 상태와 함께 읽을 수 있다. |
| [ ] | 기능 가이드·릴리스 노트 | `/guide`의 5개 locale 번들 콘텐츠와 `frontend/src/releaseNotes/**`; 별도 API 없음 | B4-G 설정·공개 | dashboard/calendar/team/friends/settings 안내, 전체 펼침/접기, 릴리스 노트 5개씩 더 보기와 외부 PR 링크를 웹 콘텐츠 범위에서 제공한다. 새 guide API는 만들지 않는다. |
| [ ] | 공개 캘린더 링크 | 웹 URL `/duty/{memberId}`; 조회 조합은 members/duty/schedules/dday/calendar/holidays/teams | B4-A 홈·캘린더, B4-G 설정·공개 | 별도 share token이나 새 공개 API를 만들지 않는다. 기존 HTTPS 링크를 공유·열기하고 앱이 열 수 있으면 동일 member 캘린더로, 그렇지 않으면 기존 웹으로 이동한다. 익명 PUBLIC 권한은 서버와 동일하다. |
| [ ] | 알 수 없는 링크·경로 | 웹 `not-found`와 동등한 fallback | B4-A 홈·캘린더 | 지원하지 않는 딥링크는 crash나 권한 우회 없이 홈 또는 안내 화면으로 이동한다. |
| [ ] | 계정 삭제 안내·로그아웃 | 웹은 실제 삭제 API 없이 안내만 제공; 로그아웃은 `POST /api/auth/logout` | B4-G 설정·공개 | **웹 기능 동등성 범위에서는 안내만 재현**하고 임의의 삭제 API를 만들지 않는다. App Store 제출을 위한 실제 삭제는 B5의 별도 승인·설계 항목으로 관리한다. |

### 12.8 범위에서 명시적으로 제외하는 항목

- [x] 서비스 관리자 전용 `/admin`, `/admin/teams`, `/admin/dev`, `/admin/api/**`는 iOS에 구현하지 않는다.
- [x] `TeamManageView`에 서비스 관리자에게만 보이는 빈 팀 삭제는 iOS에 구현하지 않는다.
- [x] 오프라인 읽기 캐시, 오프라인 쓰기, 충돌 해결은 이번 기능 동등성 완료 조건이 아니다.
- [x] PWA 설치 가이드, Service Worker, 브라우저 VAPID 구독 UI를 네이티브 앱에 복제하지 않는다. 기존 웹/PWA 코드는 유지한다.
- [x] Attachment enum의 `TEAM`, `PROFILE`을 근거로 신규 일반 첨부 UI를 만들지 않는다. 현재 웹의 일정·Todo 첨부와 별도 프로필 사진 API만 구현한다.
- [x] 서버에만 존재하고 현재 웹 UI가 쓰지 않는 `DELETE /api/duty/override`, Todo legacy 목록·calendar/due/overdue/position endpoint를 새 앱 기능으로 노출하지 않는다.
- [x] Kakao/Naver 연결 해제, 별도 공개 share token, 시스템 자동 테마, 실제 회원 탈퇴는 현재 웹 기능을 넘어가므로 이 매트릭스의 동등성 구현에 포함하지 않는다.

### 12.9 동등성 착수 전 확인 게이트

다음은 앱에서 임의로 우회하거나 웹보다 확장하지 않는다. 공통 서버 계약을 고치면 웹에 영향을 줄 수 있으므로 영향·대안·웹 회귀안을 사용자에게 먼저 제시한다.

| ID | 확인 대상 | 현재 차이 | 완료 전 게이트 |
|---|---|---|---|
| FM-G01 | 일정 검색 DTO | 웹은 `id/description/hasAttachments` 등을 기대하지만 서버 검색 응답 필드는 다르다. | iOS 검색 모델을 고정하기 전에 실제 응답과 웹 동작을 계약 테스트로 확인한다. 공통 DTO 변경이 필요하면 사용자 승인 후 웹과 앱을 함께 검증한다. |
| FM-G02 | 일정·Todo 첨부 편집 | `orderedAttachmentIds` 누락은 기존 첨부 전체 삭제로 해석될 수 있다. | 앱의 기존 ID 명시·정렬 코드는 구현됐다. fixture/통합 테스트로 편집·제거·정렬을 최종 검증하며 서버 의미는 사용자 승인 없이 바꾸지 않는다. |
| FM-G03 | 첨부 용량 | 웹·백엔드는 50MB를 표시하지만 운영 proxy 제한은 10MB일 수 있다. | 앱은 10MB 제한과 HEIC→JPEG 변환을 구현했다. 실제 운영 제한을 확인해 사용자 노출 한도를 정하고 웹 노출/서버 설정 변경은 먼저 협의한다. |
| FM-G04 | 근무 편집 권한 | 서버의 일부 쓰기 권한이 웹 UI의 본인/개인 위임 manager 범위보다 넓다. | 앱은 현재 웹 UI 범위를 유지한다. 서버 권한 자체를 변경하지 않는다. |
| FM-G05 | 팀 관리 권한 | 일부 액션은 일반 팀 매니저에게 웹에서 보이지만 서버가 거절하고, 대표 관리자 변경 API는 예상보다 넓게 허용될 수 있다. | 현재 권한과 오류를 재현해 정확한 계약을 고정한다. 정책 변경은 웹 동작에 영향을 주므로 별도 사용자 승인 대상으로 올린다. |
| FM-G06 | 개인 관리자 후보 | 웹은 가족만 후보로 제한하지만 서버 assign API에는 같은 제한이 없다. | 앱은 가족만 표시하고 서버 정책을 이번 범위에서 강화하지 않는다. |
| FM-G07 | APNs | 기존 `/api/auth/push/**`는 VAPID Web Push라 네이티브 device token과 호환되지 않는다. | additive `/api/auth/push/apns/register`, `/unregister`와 별도 installation/sender를 구현했다. 실제 기기와 기존 PWA 구독·발송·badge 교차 회귀 전에는 완료 처리하지 않는다. |
| FM-G08 | 날짜·시간 | 일정 계약은 timezone 없는 `LocalDateTime`이다. | 앱의 로컬 날짜 직렬화 코드·테스트는 구현됐다. 실제 서버 E2E로 웹과 같은 달력 의미를 확인하고 공통 계약 변경은 별도 승인 대상으로 둔다. |
