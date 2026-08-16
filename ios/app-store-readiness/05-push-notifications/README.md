# APNs 푸시 알림 출시 준비

## 현재 상태

- 앱의 권한 요청, 기기 token 수신, 서버 등록·해제와 서명 entitlement 기반 APNs 환경 분리는 구현돼 있다.
- 서버는 installation을 현재 refresh session에 귀속하고 같은 device token의 소유 session을 최신 등록으로 이전한다.
- 서버는 installation의 sandbox 여부에 따라 APNs endpoint를 선택하며 양쪽 endpoint에 같은 Team scoped 키를 사용한다.
- 앱 내부 푸시 OFF→ON, 로그아웃→다른 계정 로그인, 늦은 token callback과 register/unregister 경합은 자동 테스트로 고정돼 있다.
- 남은 일은 Apple 운영 키 설정, sandbox·production 실수신, 알림 이동과 PWA 회귀 검증이다.

## APNs 키와 서버 설정

Apple Developer에서 Environment가 `Sandbox & Production`, Key Restriction이 `Team Scoped (All Topics)`인 APNs 키 하나를 사용한다.

```dotenv
APNS_TEAM_ID=<Apple Developer Team ID>
APNS_KEY_ID=<APNs Key ID>
APNS_PRIVATE_KEY='<APNs .p8 전체 내용>'
```

- `APNS_TEAM_ID`는 키가 속한 Apple Developer team ID이며 Sign in with Apple의 team ID와 같을 수 있다.
- `APNS_KEY_ID`는 `APNS_PRIVATE_KEY`의 `.p8`을 발급한 키와 반드시 일치해야 한다.
- private key는 실제 줄바꿈을 보존하거나 줄바꿈을 literal `\n`으로 넣는다. secret manager와 Compose가 최종 컨테이너에 전달한 값이 손상되지 않았는지 확인한다.
- `.p8`은 다시 다운로드할 수 없으므로 Git, 문서, 이미지, 로그에 복사하지 말고 secret manager에 보관한다.
- 개발 서명으로 직접 설치한 앱은 signed `aps-environment=development`를 기준으로 Sandbox endpoint를, TestFlight/App Store 앱은 `aps-environment=production`을 기준으로 Production endpoint를 사용한다.
- 세 변수 중 하나라도 비어 있으면 APNs 발송은 비활성화된다.

키를 전환할 때는 새 key ID와 그에 대응하는 `.p8`을 같은 배포에서 함께 교체하고 앱 컨테이너를 재생성한다. Sandbox와 Production 실기기 수신을 모두 확인한 뒤 이전 키를 폐기한다.

## 남은 체크

### Apple 및 운영 서버

- [ ] 양 환경에 접근 가능한 APNs Auth Key(`.p8`)를 생성하고 소유자와 rotation 책임자를 확정한다.
- [ ] `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_PRIVATE_KEY`를 secret manager에 등록하고 줄바꿈 손상 없이 서버가 읽는지 확인한다.
- [ ] Release 서명 Archive에서 `aps-environment=production`, bundle identifier와 `apns-topic` 일치를 확인한다.
- [ ] sandbox token은 sandbox host, TestFlight production token은 production host로만 발송되는지 확인한다.
- [ ] APNs 오류 reason과 400/403/410/429/5xx를 민감값 없이 관찰할 수 있고, 410 token 정리가 실제 운영에서 동작하는지 확인한다.

### 실기기 수신과 계정 전환

- [ ] Debug 실기기에서 권한 허용·거부, 앱 내부 OFF→ON, sandbox 알림 수신을 확인한다.
- [ ] TestFlight에서 foreground/background/종료 상태의 production 알림 표시, sound, badge를 확인한다.
- [ ] A 계정 로그아웃 후 B 계정 로그인 시 installation이 B session으로 이전되고 A 계정 알림이 더 이상 오지 않는지 확인한다.
- [ ] offline 복귀, token 변경과 앱 재설치 후 중복 installation 없이 재등록되는지 확인한다.

### 알림 이동과 웹 회귀

- [ ] 알림 탭이 앱 상태와 관계없이 같은 목적 화면으로 이동하고, 읽음 처리 실패가 화면 이동을 막지 않는지 확인한다.
- [ ] `notificationId` 누락, 삭제됐거나 권한 없는 일정·Todo가 안전한 fallback으로 끝나는지 확인한다.
- [ ] badge가 서버 unread count, 앱 내 읽음 처리와 로그아웃 뒤 상태에 맞는지 확인한다.
- [ ] 한국어·영어 payload의 localization key와 argument 순서를 실제 수신으로 확인한다.
- [ ] iOS APNs 추가 후 기존 Web Push/PWA 구독, 발송, 알림 클릭 이동이 회귀하지 않았는지 확인한다.

## 완료 조건

- Debug sandbox와 TestFlight production에서 각각 실제 알림을 수신한다.
- 앱 내부 OFF→ON과 계정 전환이 재실행 없이 현재 session의 푸시로 복구된다.
- foreground/background/종료 상태의 표시, badge와 알림 이동이 실기기에서 통과한다.
- 운영 키는 secret manager에만 있고 APNs 실패와 만료 token 정리를 관찰할 수 있다.
- 기존 PWA 알림 흐름이 그대로 동작한다.

## 불변 계약

- installation 소유자는 access token이 아니라 현재 refresh session으로 결정한다.
- 같은 device token을 재등록하면 가장 최근의 유효한 session이 소유한다.
- 로그아웃은 인증 쿠키가 유효할 때 unregister를 먼저 시도하며, 늦은 callback이나 요청 경합이 이전 계정 소유권을 되살려서는 안 된다.
- Debug는 sandbox, TestFlight/App Store는 production APNs를 사용한다.
- `.p8`, session cookie, device token 원문과 기타 비밀값을 Git, 문서, 이미지, 로그에 남기지 않는다.
- APNs 기능 변경으로 기존 Web Push/PWA 동작을 깨뜨리지 않는다.

## 필요한 실행 및 참고

- iOS 등록: [APNsRegistration.swift](../../Dutypark/Features/Notifications/APNsRegistration.swift)
- 앱 연결: [DutyparkApp.swift](../../Dutypark/App/DutyparkApp.swift), [RootTabView.swift](../../Dutypark/App/RootTabView.swift)
- 알림 이동: [NotificationStore.swift](../../Dutypark/Features/Notifications/NotificationStore.swift), [NotificationPresentation.swift](../../Dutypark/Features/Notifications/NotificationPresentation.swift)
- 서버 등록: [ApnsInstallationController.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/push/apns/controller/ApnsInstallationController.kt), [ApnsInstallationService.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/push/apns/service/ApnsInstallationService.kt)
- 서버 발송: [ApnsPushService.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/push/apns/service/ApnsPushService.kt)
- 자동 회귀: [NotificationFeatureTests.swift](../../DutyparkTests/NotificationFeatureTests.swift)
- [Apple: Registering your app with APNs](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns)
- [Apple: Establishing a token-based connection to APNs](https://developer.apple.com/documentation/usernotifications/establishing-a-token-based-connection-to-apns)
- [Apple: Handling notifications](https://developer.apple.com/documentation/usernotifications/handling-notifications-and-notification-related-actions)
