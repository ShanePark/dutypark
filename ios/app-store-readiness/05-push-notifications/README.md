# APNs 푸시 알림 출시 준비

- 작성일: 2026-08-12
- 우선순위: P0(실기기·TestFlight 검증 필수)
- 범위: 권한, APNs 등록, 세션 연결, 서버 발송, 환경 분리, 알림 이동

## 목표

사용자가 푸시를 껐다 켜거나 로그아웃 후 다른 계정으로 로그인해도 현재 기기 토큰이 정확한 refresh session에 연결되게 한다.
Debug sandbox와 TestFlight/App Store production APNs를 분리하고, 운영 키를 소스나 문서에 남기지 않는다.

## 현재 확인된 상태

- [Dutypark.entitlements](../../Dutypark/Dutypark.entitlements)에 `aps-environment`와 Associated Domains가 선언되어 있다.
- [project.pbxproj](../../Dutypark.xcodeproj/project.pbxproj)는 Debug를 `development`, Release를 `production`으로 설정한다.
- [DutyparkApp.swift](../../Dutypark/App/DutyparkApp.swift)가 `NotificationAppDelegate`를 연결한다.
- [APNsRegistration.swift](../../Dutypark/Features/Notifications/APNsRegistration.swift)가 시스템 권한, 기기 토큰 수신, 서버 등록·해제를 담당한다.
- Debug 빌드는 `sandbox: true`, Release 빌드는 `sandbox: false`를 서버에 전송한다.
- 서버 endpoint는 [ApnsInstallationController.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/push/apns/controller/ApnsInstallationController.kt)의 `/api/auth/push/apns/register|unregister`다.
- [ApnsInstallationService.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/push/apns/service/ApnsInstallationService.kt)는 기기 토큰을 현재 refresh token에 연결한다.
- 같은 device token이 다시 등록되면 새로운 refresh session으로 소유 관계를 갱신한다.
- [ApnsPushService.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/push/apns/service/ApnsPushService.kt)는 sandbox/production host를 구분하고 ES256 provider token으로 발송한다.
- [application.yml](../../../src/main/resources/application.yml)은 Team ID, Key ID, private key를 환경 변수에서 받도록 되어 있다.
- APNs 410 응답을 받은 installation은 제거한다.
- [RootTabView.swift](../../Dutypark/App/RootTabView.swift)는 인증 화면 진입과 foreground 복귀 때 등록 재개를 호출한다.

## 확인된 재등록 결함

`APNsRegistrationManager`의 `hasRequestedRemoteRegistration`은 한 프로세스 동안 한 번 `true`가 된 뒤 다시 초기화되지 않는다.
푸시 OFF 시 서버 unregister와 저장 토큰 삭제는 하지만 이 플래그는 그대로다.
그 뒤 ON으로 바꾸면 `registerWithSystemIfNeeded()`가 조기 반환하여 APNs callback을 다시 받지 못하고 서버 재등록도 일어나지 않는다.
로그아웃 때 토큰을 삭제한 후 같은 앱 프로세스에서 재로그인해도 같은 이유로 새 refresh session에 installation을 연결하지 못할 수 있다.
또한 탭의 로그아웃 동선은 [RootTabView.swift](../../Dutypark/App/RootTabView.swift)에서 `session.logout()`만 호출하여 설정 화면의 로그아웃과 APNs 해제 순서가 다르다.

## 해야 할 일

### 1. 등록 상태 모델 수정

- [ ] `registerForRemoteNotifications()` 호출 여부와 서버 등록 완료 여부를 별도 상태로 관리한다.
- [ ] 이미 시스템 등록된 경우 저장된 token으로 서버 register를 다시 호출할 수 있게 한다.
- [ ] OFF→ON에서 현재 권한이 authorized/provisional이면 서버 연결을 반드시 복원한다.
- [ ] 로그아웃→재로그인 시 같은 token을 새 refresh session에 다시 연결한다.
- [ ] `didRegister...` API 실패 시 token을 보존하고 인증 복구 뒤 서버 등록만 재시도한다.
- [ ] `didFail...` 또는 timeout 뒤 foreground 복귀에서 제한된 backoff로 재시도한다.
- [ ] OS 권한 denied와 앱 내부 OFF를 서로 다른 상태와 안내 문구로 표시한다.
- [ ] 앱 설정에서 OFF일 때 시스템 권한 자체를 되돌릴 수 없다는 점을 정확히 안내한다.

### 2. 세션 생명주기와 연결

- [ ] 로그아웃 함수를 중앙화하여 APNs unregister를 인증 쿠키가 유효할 때 먼저 요청한다.
- [ ] 설정 화면, 탭 메뉴, 세션 만료 등 모든 로그아웃 경로가 같은 흐름을 사용한다.
- [ ] unregister 실패 시 installation이 이전 계정에 남지 않도록 다음 로그인 register가 소유권을 덮어쓴다.
- [ ] 다른 계정 로그인 직후 stored token을 현재 refresh session으로 등록한다.
- [ ] refresh token 회전 시 installation foreign key가 새 세션으로 이동하거나 유효하게 유지되는지 정한다.
- [ ] 서버 로그아웃·전체 세션 삭제·회원 탈퇴 시 연결된 installation 정리 정책을 검증한다.
- [ ] impersonation 중에는 실제 session owner와 알림 수신 대상 정책을 명확히 한다.
- [ ] 여러 기기와 한 기기의 여러 계정 전환을 각각 지원한다.

### 3. Apple Developer와 Xcode 설정

- [ ] Explicit App ID `com.tistory.shanepark.dutypark`에 Push Notifications capability를 활성화한다.
- [ ] 개발·배포 provisioning profile을 갱신하고 실제 entitlement를 archive에서 확인한다.
- [ ] Debug archive가 아닌 Release archive에 production `aps-environment`가 들어가는지 확인한다.
- [ ] Apple Developer에서 APNs Auth Key(`.p8`)를 생성하거나 기존 전용 키의 소유자를 확인한다.
- [ ] Key ID와 Apple Developer Team ID를 배포 secret manager에 등록한다.
- [ ] `.p8` 원문은 Git, Markdown, 빌드 로그, 컨테이너 이미지에 넣지 않는다.
- [ ] 키 교체 담당자, 만료/폐기 절차, 긴급 rotation 절차를 운영 문서에 남긴다.
- [ ] 서버의 `apns-topic`이 실제 bundle identifier와 일치하는지 확인한다.

### 4. 서버 환경과 발송 신뢰성

- [ ] `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_PRIVATE_KEY`가 운영에서 모두 주입되는지 secret 이름만 확인한다.
- [ ] multiline `.p8`의 줄바꿈이 배포 환경에서 손상되지 않는지 startup health check로 검증한다.
- [ ] sandbox token은 `api.sandbox.push.apple.com`, production token은 `api.push.apple.com`으로만 보낸다.
- [ ] TestFlight는 production APNs token을 사용한다는 전제로 검증한다.
- [ ] 400/403/410/429/5xx와 APNs reason body를 민감값 없이 구조화 로그·지표로 남긴다.
- [ ] `BadDeviceToken`은 환경 불일치부터 확인하고 무한 재시도하지 않는다.
- [ ] `Unregistered`/410은 해당 token을 정리하며 일시 오류는 제한된 재시도 정책을 적용한다.
- [ ] provider JWT는 Apple 제한에 맞춰 재사용·갱신하고 발송마다 불필요하게 생성하지 않도록 검토한다.
- [ ] payload 크기 제한과 현지화 key 누락을 자동 테스트한다.

### 5. 알림 표시와 이동

- [ ] foreground에서 banner, sound, badge 동작을 제품 정책대로 확인한다.
- [ ] background와 종료 상태에서 알림 탭이 동일한 목적지로 이동한다.
- [ ] `notificationId`가 없는 구형/오류 payload도 앱을 중단시키지 않는다.
- [ ] 알림 탭 시 서버 읽음 처리 실패와 화면 이동을 분리해 사용자가 목적지를 열 수 있게 한다.
- [ ] 삭제되었거나 권한 없는 일정·Todo는 안전한 오류 화면으로 폴백한다.
- [ ] 앱 badge가 서버 unread count, 앱 내 읽음 처리, 로그아웃과 일치한다.
- [ ] 다섯 언어의 `loc-key`와 `loc-args` 개수·순서를 확인한다.

## 구현 대상 파일

- iOS 등록: [APNsRegistration.swift](../../Dutypark/Features/Notifications/APNsRegistration.swift)
- 앱 연결: [DutyparkApp.swift](../../Dutypark/App/DutyparkApp.swift), [RootTabView.swift](../../Dutypark/App/RootTabView.swift)
- 설정 UI: [SettingsView.swift](../../Dutypark/Features/Settings/SettingsView.swift)
- 알림 이동: [NotificationStore.swift](../../Dutypark/Features/Notifications/NotificationStore.swift), [NotificationPresentation.swift](../../Dutypark/Features/Notifications/NotificationPresentation.swift)
- entitlement: [Dutypark.entitlements](../../Dutypark/Dutypark.entitlements), [project.pbxproj](../../Dutypark.xcodeproj/project.pbxproj)
- 서버 등록: [ApnsInstallationController.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/push/apns/controller/ApnsInstallationController.kt), [ApnsInstallationService.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/push/apns/service/ApnsInstallationService.kt)
- 서버 발송: [ApnsPushService.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/push/apns/service/ApnsPushService.kt), [NotificationEventListener.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/notification/event/NotificationEventListener.kt)

## 테스트 매트릭스

| 빌드/상태 | 설치·계정 조건 | 기대 결과 |
|---|---|---|
| Debug 실기기 | 최초 설치, 권한 허용 | sandbox token 등록, 개발 APNs 수신 |
| Debug 실기기 | 권한 거부 | 앱 정상 사용, 설정 이동 안내, 반복 prompt 없음 |
| Debug 실기기 | 앱 OFF→ON | 같은 token을 현재 session에 재등록 |
| Debug 실기기 | A 로그아웃→B 로그인 | installation 소유자가 B session으로 변경 |
| TestFlight | 신규 설치 | production token 등록, 운영 APNs 수신 |
| TestFlight | foreground/background/종료 | 표시·badge·탭 이동이 일관됨 |
| 모든 환경 | offline 후 복귀 | backoff 뒤 중복 없는 재등록 |
| 모든 환경 | token 변경/앱 재설치 | 새 token 저장, 만료 token 정리 |

- [ ] [NotificationFeatureTests.swift](../../DutyparkTests/NotificationFeatureTests.swift)에 OFF→ON, 재로그인, 실패 재시도 상태 테스트를 추가한다.
- [ ] [ApnsInstallationControllerTest.kt](../../../src/test/kotlin/com/tistory/shanepark/dutypark/push/apns/controller/ApnsInstallationControllerTest.kt)에 refresh cookie 누락·타 계정 세션을 추가한다.
- [ ] [ApnsInstallationServiceTest.kt](../../../src/test/kotlin/com/tistory/shanepark/dutypark/push/apns/service/ApnsInstallationServiceTest.kt)에 token 소유권 이전과 세션 폐기를 추가한다.
- [ ] [ApnsPushServiceTest.kt](../../../src/test/kotlin/com/tistory/shanepark/dutypark/push/apns/service/ApnsPushServiceTest.kt)에 host 분기, APNs 오류 reason, payload 현지화를 추가한다.

## 완료 조건

- [ ] OFF→ON과 로그아웃→다른 계정 로그인이 앱 재실행 없이 푸시를 정상 복구한다.
- [ ] 모든 로그아웃 진입점이 같은 APNs/session 정리 흐름을 사용한다.
- [ ] Debug sandbox와 TestFlight production에서 각각 실제 알림을 수신한다.
- [ ] archive entitlement, bundle ID, APNs topic, provisioning profile이 일치한다.
- [ ] 운영 키는 secret manager에만 있고 저장소·로그·문서에 비밀값이 없다.
- [ ] foreground/background/종료 상태의 표시, badge, 딥링크가 실기기에서 통과한다.
- [ ] APNs 실패율과 만료 token 정리를 운영에서 관찰할 수 있다.

## Apple 공식 참고

- [Registering your app with APNs](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns)
- [Establishing a token-based connection to APNs](https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns)
- [Generating a remote notification](https://developer.apple.com/documentation/usernotifications/generating-a-remote-notification)
- [Handling notifications and notification-related actions](https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions)
