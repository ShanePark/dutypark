# 11. 릴리스 엔지니어링과 App Store 빌드

- 기준일: 2026-08-15
- 상태: development 서명, Apple Distribution 인증서, Release Archive 생성·Validate App·App Store Connect 업로드 완료, Connect 처리와 최종 패키징 검증 대기
- 공식 절차: [Distribute an app through the App Store](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)

2026-08-14 Xcode `Manage Certificates`에서 Apple Distribution 인증서가 생성되어 목록에 표시되는 것을 확인했다. 인증서 소유자의 개인 식별 정보는 이 문서에 기록하지 않는다.

2026-08-15 Xcode 26.6 Organizer에서 `Dutypark` **1.0 (1)**이 Team과 연결된 arm64 `iOS App Archive`로 생성된 것을 확인했다.

같은 날 Organizer의 권장 App Store Connect 설정으로 Validate App을 실행했고, `Dutypark` **1.0 (1)**이 경고 없이 모든 validation check를 통과했다. 이어 App Store Connect 배포를 실행해 Xcode의 `App upload complete` 결과를 확인했다. Connect의 빌드 처리 완료와 업로드된 바이너리의 최종 entitlement 확인은 아직 남아 있다.

이 문서는 **심사 후보 바이너리의 생성·검증·보관·배포 통제**만 다룬다.
App Store 메타데이터와 심사 정보는 [07. App Store Connect](../07-app-store-connect/README.md), TestFlight 시나리오와 App Review 실행은 [08. TestFlight 및 App Review](../08-testflight-and-review/README.md)를 따른다.

## 1. App Store distribution Archive

- [x] Xcode 계정에 Apple Distribution 인증서를 생성하고 유효 상태를 확인한다.
- [x] App Store Connect 앱 레코드와 `io.github.shanepark.dutypark` Bundle ID가 일치하는지 확인한다.
- [x] Generic iOS Device의 **Release Archive** `Dutypark` 1.0 (1)을 생성하고 Organizer에서 `iOS App Archive`임을 확인한다.
- [x] 권장 App Store Connect 설정으로 Validate App을 실행해 distribution 검증을 통과한다.
- [x] 검증한 `Dutypark` 1.0 (1)을 App Store Connect에 업로드하고 Xcode의 완료 결과를 확인한다.
- [ ] 마케팅 버전과 빌드 번호가 이전 업로드보다 크고 Archive·업로드 빌드·출시 기록에서 일치한다.
- [ ] 최종 서명 entitlement의 Team/App ID, `aps-environment=production`, Associated Domains와 Sign in with Apple capability를 확인한다.
- [ ] 개발 URL, 테스트 플래그·계정, verbose logging, 내부 문서·fixture와 비밀 파일이 앱 번들에 없음을 확인한다.
- [x] Xcode Organizer의 **Validate App**을 경고 없이 통과한다.

검증은 development 서명 빌드나 unsigned Archive가 아니라 실제 업로드할 distribution Archive를 기준으로 한다.

## 2. dSYM·Privacy·패키징 검증

- [ ] 앱 바이너리와 dSYM의 UUID가 일치하고, 해당 dSYM을 릴리스 산출물과 함께 보관한다.
- [ ] crash 수집 서비스를 사용한다면 같은 빌드의 dSYM 업로드와 조회 가능 여부를 확인한다.
- [ ] [PrivacyInfo.xcprivacy](../../Dutypark/PrivacyInfo.xcprivacy)와 포함된 SDK manifest가 최종 앱 번들에 존재한다.
- [ ] Organizer Privacy Report를 내보내 [개인정보·AI 문서](../03-privacy-and-ai-consent/README.md)와 App Store Connect App Privacy 답변을 대조한다.
- [ ] Required Reason API, tracking domain과 third-party SDK signature 관련 경고가 없다.
- [ ] 앱 아이콘, 표시 이름, 최소 iOS, iPhone 전용·세로 방향, 암호화 수출 규정 값이 최종 Archive와 제출 정보에서 일치한다.

## 3. 빌드 재현성과 산출물

- [ ] 사용할 Xcode·macOS 버전과 clean build, test, archive, validation 명령을 릴리스 기록에 고정한다.
- [ ] Archive, dSYM, export/validation 로그, 테스트 `.xcresult`, Privacy Report와 검증 체크 결과를 접근 통제된 위치에 보관한다.
- [ ] 인증서, `.p8`, provisioning profile 비밀번호와 심사 계정 비밀번호는 저장소·로그·산출물에 포함하지 않는다.
- [ ] 같은 소스와 설정에서 Archive를 다시 생성할 수 있도록 수동 절차의 담당자와 필요한 외부 설정을 문서화한다.

## 4. CI 도입 판단과 배포 위험

CI 자체는 첫 제출의 필수 조건이 아니다. 다만 수동 절차가 재현되지 않거나 반복 업로드 위험이 크면 출시 전에 최소 파이프라인을 만든다.

- [ ] iOS 전용 변경이 `main`에 병합될 때 백엔드 배포를 불필요하게 유발하지 않도록 workflow path filter 또는 배포 조건을 확정한다.
- [ ] PR에서는 서명 없는 build·test를 실행하고, distribution 자산은 보호된 릴리스 작업에서만 사용한다.
- [ ] 업로드는 보호된 branch/tag, 승인된 버전·빌드와 수동 승인으로 제한한다.
- [ ] 중복 빌드 번호, 잘못된 환경 URL, production APNs 누락과 비밀 로그 노출을 업로드 전에 차단한다.
- [ ] 자동화하지 않는다면 두 번째 사람이 Archive 설정·Validate 결과·업로드 대상을 교차 확인한다.

## 5. 출시·중단·롤백

- [ ] 단계적 배포 여부, 출시 승인자, 모니터링 담당자와 중단 결정권자를 정한다.
- [ ] 크래시, 로그인, 계정 삭제, APNs, Universal Link와 핵심 CRUD의 출시 후 지표·경보를 정한다.
- [ ] 즉시 중단 기준을 개인정보·인증 오류, 데이터 손상, 치명적 크래시와 핵심 기능 불가 수준으로 구체화한다.
- [ ] App Store 판매 중단·단계적 배포 일시정지와 서버 feature/config rollback 절차를 실제 담당자가 실행 가능하게 준비한다.
- [ ] 클라이언트 바이너리는 즉시 되돌릴 수 없음을 전제로 이전 앱 버전과 서버 API의 하위 호환 기간을 정한다.
- [ ] hotfix 빌드 번호 증가, 회귀 검증, 긴급 심사 요청과 사용자 공지 경로를 준비한다.

## 완료 조건

- [ ] 심사 후보 distribution Archive가 Validate App을 통과하고 서명·entitlement·dSYM·Privacy Report·번들 검증을 완료했다.
- [ ] 동일 빌드의 테스트 결과와 모든 릴리스 산출물을 보관했다.
- [ ] 업로드 통제, 출시 모니터링, 중단·서버 rollback·hotfix 절차와 담당자가 확정됐다.
