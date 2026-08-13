# 11. 릴리스 엔지니어링과 App Store 빌드

- 기준일·최종 확인일: 2026-08-13
- 상태: 수동 빌드 가능, 배포 파이프라인 정비 필요
- 기존 문서: [iOS README](../../README.md), [기존 배포 체크리스트](../../DEPLOYMENT_CHECKLIST.md)
- 공식 절차: [Distribute an app through the App Store](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)

## 현재 상태 요약

- 저장소에서 iOS 전용 CI 구성은 확인되지 않는다.
- 로컬 빌드·테스트 명령은 [iOS README](../../README.md)에 문서화되어 있다.
- 프로젝트의 `DEVELOPMENT_TEAM` 값은 현재 빈 문자열이다.
- 현재 Xcode Bundle ID는 `com.tistory.shanepark.dutypark`이며, 출시 목표 후보 `io.github.shanepark.dutypark`는 Apple 멤버십 승인 후 Explicit App ID 가용성 확인 전까지 미확정이다.
- Apple Developer Program은 개인 주체 가입·결제를 완료했고 승인을 기다리는 중이다.
- 앱 타깃 버전은 `MARKETING_VERSION = 1.0`, 빌드는 `CURRENT_PROJECT_VERSION = 1`이다.
- 자동 서명 설정과 entitlement 파일은 있으나 실제 배포 팀·프로필 검증이 필요하다.
- [PrivacyInfo.xcprivacy](../../Dutypark/PrivacyInfo.xcprivacy)가 앱 타깃에 포함되어 있다.
- Privacy Manifest에는 현재 수집하는 Name, Email, Photos or Videos, Other User Content, User ID, Device ID와 Other Data Types가 App Functionality·user-linked·non-tracking으로 선언되어 있다.
- Release Archive 생성, 업로드 및 보관 절차는 아직 재현 가능한 자동화로 고정되지 않았다.

프로젝트 설정 근거는 [project.pbxproj](../../Dutypark.xcodeproj/project.pbxproj), [Dutypark.xcscheme](../../Dutypark.xcodeproj/xcshareddata/xcschemes/Dutypark.xcscheme), [Dutypark.entitlements](../../Dutypark/Dutypark.entitlements), [Info.plist](../../Dutypark/Info.plist)다.

## 출시 전 필수 체크리스트

- [ ] Apple Developer Program 팀과 App Store Connect 권한을 확정한다.
- [ ] Xcode 프로젝트 Release 설정에 실제 Team을 연결한다.
- [ ] Bundle ID와 App Store Connect 앱 레코드가 정확히 일치한다.
- [ ] Distribution certificate와 App Store provisioning profile을 준비한다.
- [ ] macOS 실행 환경에서 clean build, test, archive를 재현한다.
- [ ] 마케팅 버전과 빌드 번호가 이전 업로드보다 증가했다.
- [ ] Archive 안의 앱, dSYM, privacy manifest, entitlement를 검증한다.
- [x] unsigned generic iOS Release Archive의 앱 번들에 불필요한 내부 문서와 개발용 파일이 포함되지 않는다.
- [x] unsigned generic iOS Release Archive의 앱 아이콘, 표시 이름, 최소 iOS와 iPhone 전용·세로 방향 기술 설정이 프로젝트와 일치한다.
- [x] 현재 소스·의존성·unsigned Release Archive 기준으로 비면제 암호화 미사용 선언의 기술 근거를 확인한다.
- [x] 현재 소스·의존성·unsigned Release Archive 기준으로 Required Reason API·tracking 선언과 embedded third-party framework를 사전 대조한다.
- [ ] 배포 서명된 Release Archive에서도 같은 번들 제외 검증을 반복한다.
- [ ] TestFlight 내부 테스트를 거쳐 동일 빌드를 심사에 연결한다.
- [ ] 릴리스 산출물과 결과 로그를 정해진 위치에 보관한다.

## 1. macOS CI 또는 전용 빌드 환경

iOS 빌드는 Xcode가 설치된 macOS runner에서 실행해야 한다.
초기에는 수동 Archive도 가능하지만, 제출 직전 검증은 동일한 명령과 Xcode 버전으로 반복 가능해야 한다.

권장 CI 단계:

1. 사용 Xcode 버전을 선택하고 `xcodebuild -version`을 기록한다.
2. 의존성을 해석하고 시뮬레이터용 Debug build를 수행한다.
3. 단위 테스트와 UI 테스트를 실행하고 `.xcresult`를 보관한다.
4. Release 설정으로 Generic iOS Device Archive를 생성한다.
5. Archive 검증 스크립트로 번들·서명·메타데이터를 점검한다.
6. 승인된 릴리스에서만 App Store Connect로 업로드한다.

CI는 pull request에서 서명 없는 시뮬레이터 테스트를 우선 수행한다.
배포 인증서와 App Store Connect API key는 보호된 릴리스 작업에서만 사용한다.
키 원문, `.p8`, 인증서 비밀번호, 프로비저닝 프로필을 저장소에 커밋하지 않는다.

Apple 참고: [Xcode Cloud overview](https://developer.apple.com/xcode-cloud/) 및 [Managing signing assets](https://developer.apple.com/help/account/certificates/create-a-certificate-signing-request/).

## 2. 기본 xcodebuild 검증

구체적인 시뮬레이터 대상은 [iOS README](../../README.md)의 현재 명령을 기준으로 한다.

`xcodebuild -project ios/Dutypark.xcodeproj -scheme Dutypark -configuration Release -destination 'generic/platform=iOS' -archivePath build/Dutypark.xcarchive archive`

위 예시는 명령 형태이며 Team과 서명 자산이 준비된 환경에서만 성공한다.
생성된 Archive를 저장소에 추가하지 않는다.

## 3. 서명과 entitlement

현재 [project.pbxproj](../../Dutypark.xcodeproj/project.pbxproj)의 `DEVELOPMENT_TEAM`이 비어 있으므로 출시 전에 팀을 연결해야 한다.
무료 Personal Team이나 임시 Bundle ID로 만든 Archive를 출시 산출물로 사용하지 않는다. Apple 승인이 완료되면 유료 개인 Developer Team으로 서명한다.

검증 항목:

- 앱의 `application-identifier`가 배포 Team ID와 Bundle ID 조합인지 확인한다.
- `aps-environment`가 배포 빌드에서 production인지 확인한다.
- Associated Domains의 운영 도메인이 실제 AASA 파일과 일치하는지 확인한다.
- Sign in with Apple을 도입하면 해당 capability와 entitlement를 확인한다.
- 개발 전용 entitlement나 잘못된 keychain group이 없는지 확인한다.
- embedded provisioning profile의 만료일과 App ID를 확인한다.

Apple 참고: [Code signing](https://developer.apple.com/support/code-signing/) 및 [Entitlements](https://developer.apple.com/documentation/bundleresources/entitlements).

## 4. 버전과 빌드 번호

`MARKETING_VERSION`은 사용자에게 보이는 버전이고 `CURRENT_PROJECT_VERSION`은 업로드별 고유 빌드 번호다.
같은 마케팅 버전을 다시 올려도 빌드 번호는 반드시 증가시킨다.
릴리스 태그, App Store Connect 빌드, Archive의 값이 서로 일치해야 한다.

- 버전 변경의 단일 책임자를 지정한다.
- TestFlight 업로드 전에 App Store Connect의 최근 빌드 번호를 확인한다.
- Archive의 `Info.plist`에서 `CFBundleShortVersionString`과 `CFBundleVersion`을 확인한다.
- 버전 번호를 비밀값이나 환경별 값으로 취급하지 않는다.

Apple 참고: [Set the version number and build string](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds-overview/).

## 5. Archive 검증

- `Products/Applications/Dutypark.app`의 Bundle ID, 버전, 최소 OS를 확인한다.
- 앱 실행 파일과 포함된 framework의 서명 유효성을 확인한다.
- Swift symbol이 포함된 dSYM이 생성되고 UUID가 바이너리와 일치하는지 확인한다.
- crash 분석 서비스가 있다면 해당 릴리스 dSYM을 안전하게 업로드한다.
- [PrivacyInfo.xcprivacy](../../Dutypark/PrivacyInfo.xcprivacy)와 SDK privacy manifest가 포함되는지 확인한다.
- Xcode Organizer의 Privacy Report를 내보내 App Privacy 응답과 비교한다.
- [개인정보·AI 상세 문서](../03-privacy-and-ai-consent/README.md)의 inventory 초안과 Release Privacy Report의 데이터 유형·목적·연결·tracking 값을 대조한다.
- Required Reason API 경고와 서드파티 SDK signature 경고가 없는지 확인한다.
- Debug URL, 개발 서버 주소, 테스트 계정, verbose logging이 Release에 남지 않았는지 확인한다.

Apple 참고: [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files) 및 [Describing data use](https://developer.apple.com/app-store/app-privacy-details/).

### 2026-08-13 Privacy Manifest source/archive preflight

[Apple의 Required Reason API 안내](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)와 [현재 API 범주 목록](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)을 기준으로 테스트 타깃을 제외한 앱 소스와 새 unsigned generic iOS Release Archive를 감사했다.

- 소스에서 사용하는 required-reason 범주는 앱 자체 preference를 읽고 쓰는 UserDefaults뿐이다. File Timestamp, System Boot Time, Disk Space, Active Keyboards 범주는 제한 검색에서 발견되지 않았다. 첨부의 `fileSizeKey`는 timestamp API가 아니다.
- manifest의 UserDefaults 단일 항목과 `CA92.1`은 [Apple의 approved reason](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons)에 명시된 앱 자체 정보 읽기·쓰기 용도와 일치한다.
- Xcode 앱 타깃에는 package product와 framework build item이 없고 저장소에 CocoaPods·Carthage·XCFramework가 없다. Archive 앱 번들에도 embedded framework·외부 dylib가 없고 실행 파일은 Apple OS framework와 `/usr/lib`만 링크한다. 현재 [Apple의 third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/) 대상 SDK가 포함됐다는 증거는 없다.
- Archive manifest는 소스 manifest와 byte 단위로 같고 `plutil`을 통과했다. 일곱 collected data type은 중복 없이 App Functionality·linked·non-tracking이며, `NSPrivacyTracking=false`, `NSPrivacyTrackingDomains=[]`다.
- exact manifest 계약 targeted test가 통과했고, iPhone 16 Pro 전체 suite를 새로 3회 실행해 매번 정확히 264/264(실패·건너뜀 0)로 통과했다. Release Simulator clean build와 unsigned generic iOS Release clean Archive도 성공했다.

이 사전 감사는 Xcode Organizer가 앱과 SDK manifest를 결합해 생성하는 Privacy Report가 아니다. 서명 Archive에서 Organizer Report를 내보낸 뒤 manifest·App Store Connect App Privacy 초안과 대조하는 항목은 미완료로 유지한다.

## 6. 내부 Markdown의 앱 번들 제외

Xcode의 synchronized group 또는 Copy Bundle Resources 설정 때문에 `.md` 파일이 자동 포함되는지 Archive에서 반드시 검사한다.

- `.app` 내부에서 `*.md`, 테스트 fixture, 샘플 JSON, 개발용 인증서 파일을 검색한다.
- 내부 문서가 발견되면 타깃 membership 또는 resource exclusion 설정에서 제외한다.
- 라이선스·폰트 고지처럼 사용자 제공이 필요한 문서는 목적을 확인한 뒤 의도적으로 포함한다.
- 제외 결과를 실제 Archive에서 재검증하며 Finder의 프로젝트 표시만 믿지 않는다.
- 문서에 비밀값을 적지 않는 원칙은 번들 제외 여부와 무관하게 유지한다.

### 2026-08-13 unsigned Release Archive 번들 감사

새 `/tmp` 경로에서 `CODE_SIGNING_ALLOWED=NO`로 generic iOS Release `clean archive`를 실행해
`Dutypark.xcarchive/Products/Applications/Dutypark.app`을 직접 검사했다. 이는 배포 후처리와 strip이 적용된
device 앱 번들의 패키징 기준선이며, 배포 인증서·provisioning profile·entitlement·Organizer Validate App을 검증한
서명 Archive는 아니다.

- 앱 번들 36개 파일 중 `.md`, `.swift`, `.xctest`, 테스트 fixture, `README`, `AGENTS`, workboard,
  Xcode project/workspace, 샘플 JSON, 인증서·키·provisioning profile은 없었다.
- 실행 파일과 리소스에 `-ui-testing-authenticated`, `-ui-testing-guest`, `test@duty.park`, `127.0.0.1`,
  `localhost`, 테스트 target 이름 및 저장소 절대 경로가 없었다. 운영 API URL은 의도된 Release 설정이므로 제외 대상이 아니다.
- `PrivacyInfo.xcprivacy`, `Assets.car`, `ko`·`en` localization, 앱 아이콘과 폰트가 포함됐다.
  `NOTICE.txt`는 내장 MapleStory 폰트의 의도된 저작권 고지다.
- 앱 `Info.plist`는 현재 Xcode 값인 Bundle ID `com.tistory.shanepark.dutypark`, 버전 `1.0`(빌드 `1`),
  최소 iOS `17.0`을 기록했다. 출시 목표 후보 `io.github.shanepark.dutypark`가 확정됐다는 의미는 아니다.
- `.xcarchive`에 dSYM이 존재하고 앱 실행 파일과 dSYM의 UUID
  `36688204-A146-3DBF-B416-6CAAA7A63439`가 일치했다.
- 같은 날 만든 Release Simulator clean build의 실행 파일에는 테스트 플래그·계정·localhost는 없었지만,
  배포 strip이 적용되지 않은 symbol table에 빌드 머신의 소스 절대 경로가 남았다. 따라서 Simulator `.app`은
  최종 배포 번들 제외 판정에 사용하지 않고, unsigned generic iOS Archive 결과를 기준선으로 삼았다.

### 2026-08-13 기본 제출 기술 설정 재검증

새 `/tmp` derived data와 Archive 경로에서 `CODE_SIGNING_ALLOWED=NO` generic iOS Release `clean archive`를
다시 생성했다. 첫 sandbox 실행은 CoreSimulatorService 접근 제한 때문에 asset catalog compile에서 중단됐고,
동일 명령을 권한이 있는 환경에서 실행해 성공했다. 성공 로그의 asset catalog compiler에는 앱 아이콘 관련
warning·error가 없었으며, AppIntents framework가 없어 metadata 추출을 건너뛴 비차단 warning만 있었다.

- 프로젝트 Release 설정과 앱 `Info.plist`는 표시 이름 `Dutypark`, 최소 iOS `17.0`, iPhone 전용
  `UIDeviceFamily = [1]`, `UISupportedInterfaceOrientations~iphone = [UIInterfaceOrientationPortrait]`로 일치했다.
- 프로젝트의 현재 `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1`은 Archive의
  `CFBundleShortVersionString = 1.0`, `CFBundleVersion = 1`과 일치했다. 이는 현재값 기록이며 제출값 확정 또는
  다음 업로드용 빌드 번호 증가를 완료했다는 의미가 아니다.
- `AppIcon.appiconset/Contents.json`은 universal iOS 1024×1024 원본 하나를 가리키며 JSON 구문 검증을 통과했다.
  원본 `AppIcon.png`는 1024×1024 RGB PNG이고 alpha channel이 없다.
- Archive `Info.plist`에는 `CFBundlePrimaryIcon`의 `CFBundleIconName = AppIcon`과
  `CFBundleIconFiles = [AppIcon60x60]`이 있다. 앱 번들에는 120×120, alpha 없는 `AppIcon60x60@2x.png`가 있고,
  `Assets.car`에는 `AppIcon` 이름의 iPhone 1024×1024 rendition이 있다.
- Xcode가 `AppIcon76x76@2x~ipad.png`와 `CFBundleIcons~ipad`도 생성했지만, 실제 지원 대상은
  `UIDeviceFamily = [1]`과 asset compile의 `--target-device iphone`으로 iPhone에 제한된다.

이 결과는 프로젝트와 unsigned device Archive의 기술 설정 일치만 확인한다. 표시 이름 `Dutypark`를 App Store
제품명으로 확정하거나, 출시 Bundle ID·배포 서명·provisioning·entitlement·Validate App을 검증한 것은 아니다.

위 검사는 지정한 개발·테스트 artifact와 문자열에 대한 범위 제한 감사다. 모든 비밀값의 부재를 전수 증명하거나
서명·entitlement·Privacy Report를 검증한 것은 아니므로 아래 완료 조건은 미완료로 유지한다.

## 7. 수출 규정 기술 근거

2026-08-13 현재 [Info.plist](../../Dutypark/Info.plist)의 `ITSAppUsesNonExemptEncryption`은 `false`다.
새 `/tmp` derived data와 Archive 경로에서 `CODE_SIGNING_ALLOWED=NO` generic iOS Release `clean archive`를
성공시킨 뒤, Archive 앱의 `Info.plist`에서도 같은 Boolean `false`를 확인했다. 현재 Bundle ID는
`com.tistory.shanepark.dutypark`이며, 이 감사는 출시 Bundle ID·배포 서명·App Store Connect 제출을 완료했다는
의미가 아니다.

현재 앱의 암호화 관련 기술 inventory는 다음과 같다.

- 운영 API와 웹 화면은 Apple `URLSession`·WebKit을 통한 HTTPS/TLS를 사용한다. Release API URL은
  `https://dutypark.o-r.kr/api/`다.
- 모바일 OAuth PKCE는 Apple `CryptoKit`의 `SHA256`과 Security의 `SecRandomCopyBytes`로 verifier·challenge를
  만든다. 앱이 암호 알고리즘을 자체 구현하거나 사용자 데이터 암호화 키를 관리하는 용도가 아니다.
- OAuth 브라우저 인증은 `ASWebAuthenticationSession`, push는 APNs·UserNotifications 등 Apple OS 기능을 사용한다.
- 앱 소스 제한 검색에서 CommonCrypto, OpenSSL, libsodium, 자체 AES/RSA/ChaCha·cipher, VPN·NetworkExtension,
  암호화 파일 저장, 종단간 암호화 메시징 구현은 발견되지 않았다.
- Xcode 앱 target에는 Swift package product dependency와 명시적 framework build item이 없고, 저장소에도
  CocoaPods·Carthage 또는 배포용 외부 framework/xcframework가 없다. Archive 앱 번들에도 내장 framework·동적
  라이브러리가 없다.
- Archive 실행 파일의 `otool -L`은 `CryptoKit.framework`, `Security.framework`,
  `AuthenticationServices.framework`, `Foundation.framework` 등 `/System/Library`·`/usr/lib`의 Apple OS
  구성요소만 표시했다. `nm -u`와 `strings`에서는 실제 앱 사용과 일치하는 CryptoKit SHA-256 및
  `SecRandomCopyBytes` 참조를 확인했고, 외부 암호화 라이브러리나 VPN API 참조는 확인되지 않았다.

[Apple의 `ITSAppUsesNonExemptEncryption` 설명](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption)은
앱과 링크한 제3자 라이브러리가 암호화를 사용하지 않거나 수출 규정 문서 제출이 면제되는 암호화만 사용할 때 값을 `NO`로
설정하도록 안내한다. [Apple의 암호화 문서 분류표](https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption)는
Apple 운영체제 내부의 암호화로 제한된 앱은 App Store Connect에 문서를 제출할 필요가 없다고 명시하고,
[수출 규정 준수 안내](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations)는
`URLSession` HTTPS 같은 OS 내장 암호화가 일반적으로 문서 제출 면제라고 설명한다. 따라서 현재 확인한 기술 범위에서는
**Apple OS 제공 암호화만 사용하며 비면제 암호화를 포함하지 않는다**는 판단과
`ITSAppUsesNonExemptEncryption = NO`가 서로 일치한다.

이 기록은 법률 자문이나 모든 암호화 부재에 대한 절대적 증명이 아니다. Apple도 앱·배포 국가에 따른 규정 판단과 정확한
면제 주장 책임이 개발자에게 있음을 [수출 규정 개요](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance)에서
안내한다. Apple의 준수 안내는 면제 암호화도 상황에 따라 미국 정부의 연간 self-classification 보고 대상이 될 수 있다고
덧붙이므로, 해당 의무는 App Store Connect 문서 제출 면제와 별도로 계정 소유자가 배포 범위에 맞춰 확인한다.
App Store Connect의 실제 질문 응답·저장과 Apple 확인은 아직 수행하지 않았다. 최종 서명 Archive를 업로드할 때
[App Store Connect 질문 절차](https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation)에
따라 당시 문구를 확인하고, 이 inventory와 다른 결과가 나오면 제출을 중단해 재검토한다.

다음 변경은 수출 규정 재검토 gate를 다시 연다.

- CryptoKit·Security 사용 범위를 PKCE hash·난수 생성 밖으로 확대하거나 CommonCrypto/OpenSSL/libsodium 등 새
  암호화 API·SDK·외부 dependency를 추가하는 경우
- 앱이 자체 또는 비표준 암호 알고리즘, VPN·NetworkExtension, 암호화 저장소·파일, E2EE 메시징, 암호화 키 생성·교환·관리
  기능을 도입하는 경우
- App Store Connect 질문, Apple 공식 기준, 배포 국가 또는 서버·클라이언트 보안 구조가 바뀌는 경우

## 8. 업로드와 TestFlight

Archive 검증이 끝나면 Xcode Organizer 또는 명시적인 export/upload 절차를 사용한다.
App Store Connect에서 빌드 처리가 끝난 뒤 export compliance, 암호화, privacy 경고를 확인한다.

- 먼저 내부 테스터 그룹에 배포한다.
- 로그인, 푸시, Universal Link, 첨부, 계정 삭제를 실제 배포 서명 빌드로 확인한다.
- TestFlight는 production APNs 환경을 사용하므로 푸시 토큰과 서버 설정을 별도로 검증한다.
- 심사에 제출할 빌드 번호를 기록하고 테스트 중 새 빌드와 혼동하지 않는다.
- 심사 직전 같은 빌드를 설치해 주요 시나리오를 한 번 더 수행한다.

Apple 참고: [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/).

## 9. fastlane 사용 여부

fastlane은 선택 사항이며 Archive와 업로드 절차가 안정된 뒤 반복 작업을 줄일 필요가 있을 때 도입한다.

도입한다면 `Fastfile`에는 테스트, archive, upload lane을 분리하고 비밀값은 CI secret으로 주입한다.
Match 같은 인증서 관리 방식을 쓸 경우 저장소 접근 권한, 암호 회전, 퇴사자 권한 회수 절차를 먼저 정한다.
도구 버전은 고정하고 자동 업로드는 보호된 branch/tag와 수동 승인으로 제한한다.

## 10. 릴리스 산출물 보관

각 제출 빌드마다 다음을 접근 제한된 artifact 저장소에 보관한다.

- `.xcarchive` 또는 재현에 필요한 확정 소스 revision과 빌드 환경 정보
- export된 dSYM과 UUID 목록
- 테스트 결과 `.xcresult` 및 실패 여부 요약
- Xcode 버전, macOS 버전, Scheme, configuration, commit SHA
- 버전·빌드 번호와 App Store Connect 처리 결과
- Privacy Report, entitlement 덤프, 서명 검증 결과
- 심사 노트와 제출 시각, 심사 피드백 및 대응 기록

보존 기간, 접근 권한, 삭제 책임자를 정하고 인증서·API key 원문은 산출물과 분리한다.

## 완료 조건

- [ ] macOS 환경에서 clean build, test, Release Archive를 연속 재현할 수 있다.
- [ ] Team, Bundle ID, 배포 인증서와 profile이 App Store Connect 설정과 일치한다.
- [ ] 버전과 빌드 번호가 고유하고 Archive·릴리스 기록에 남아 있다.
- [ ] dSYM, privacy report, privacy manifest, entitlement 및 서명 검증을 통과했다.
- [ ] 내부 Markdown, 테스트 fixture, 개발 설정과 비밀값이 앱 번들에 없다.
- [ ] TestFlight production 빌드에서 핵심 기능과 APNs를 확인했다.
- [ ] 업로드 빌드, 테스트 결과, 심사 자료와 릴리스 산출물이 보관되었다.
- [ ] CI가 없더라도 동일 명령과 고정된 Xcode 버전으로 제3자가 재현할 수 있다.
