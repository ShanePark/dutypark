# 11. 릴리스 엔지니어링과 App Store 빌드

- 기준일·최종 확인일: 2026-08-13
- 상태: 수동 빌드 가능, 배포 파이프라인 정비 필요
- 기존 문서: [iOS README](../../README.md), [기존 배포 체크리스트](../../DEPLOYMENT_CHECKLIST.md)
- 공식 절차: [Distribute an app through the App Store](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)

## 현재 상태 요약

- 저장소에서 iOS 전용 CI 구성은 확인되지 않는다.
- 로컬 빌드·테스트 명령은 [iOS README](../../README.md)에 문서화되어 있다.
- 프로젝트의 `DEVELOPMENT_TEAM` 값은 현재 빈 문자열이다.
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
- [ ] 불필요한 내부 문서와 개발용 파일이 앱 번들에 포함되지 않는다.
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
개인 Team이나 임시 Bundle ID로 만든 Archive를 출시 산출물로 사용하지 않는다.

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

## 6. 내부 Markdown의 앱 번들 제외

[ConfigNotes.md](../../Dutypark/Config/ConfigNotes.md)와 [CoreNotes.md](../../Dutypark/Core/CoreNotes.md)는 개발 문서이며 런타임 리소스가 아니다.
Xcode의 synchronized group 또는 Copy Bundle Resources 설정 때문에 `.md` 파일이 자동 포함되는지 Archive에서 반드시 검사한다.

- `.app` 내부에서 `*.md`, 테스트 fixture, 샘플 JSON, 개발용 인증서 파일을 검색한다.
- 내부 문서가 발견되면 타깃 membership 또는 resource exclusion 설정에서 제외한다.
- 라이선스·폰트 고지처럼 사용자 제공이 필요한 문서는 목적을 확인한 뒤 의도적으로 포함한다.
- 제외 결과를 실제 Archive에서 재검증하며 Finder의 프로젝트 표시만 믿지 않는다.
- 문서에 비밀값을 적지 않는 원칙은 번들 제외 여부와 무관하게 유지한다.

## 7. 업로드와 TestFlight

Archive 검증이 끝나면 Xcode Organizer 또는 명시적인 export/upload 절차를 사용한다.
App Store Connect에서 빌드 처리가 끝난 뒤 export compliance, 암호화, privacy 경고를 확인한다.

- 먼저 내부 테스터 그룹에 배포한다.
- 로그인, 푸시, Universal Link, 첨부, 계정 삭제를 실제 배포 서명 빌드로 확인한다.
- TestFlight는 production APNs 환경을 사용하므로 푸시 토큰과 서버 설정을 별도로 검증한다.
- 심사에 제출할 빌드 번호를 기록하고 테스트 중 새 빌드와 혼동하지 않는다.
- 심사 직전 같은 빌드를 설치해 주요 시나리오를 한 번 더 수행한다.

Apple 참고: [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/).

## 8. fastlane 사용 여부

fastlane은 선택 사항이며 Archive와 업로드 절차가 안정된 뒤 반복 작업을 줄일 필요가 있을 때 도입한다.

도입한다면 `Fastfile`에는 테스트, archive, upload lane을 분리하고 비밀값은 CI secret으로 주입한다.
Match 같은 인증서 관리 방식을 쓸 경우 저장소 접근 권한, 암호 회전, 퇴사자 권한 회수 절차를 먼저 정한다.
도구 버전은 고정하고 자동 업로드는 보호된 branch/tag와 수동 승인으로 제한한다.

## 9. 릴리스 산출물 보관

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
