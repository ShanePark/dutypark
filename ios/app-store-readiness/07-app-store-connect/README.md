# Apple Developer 및 App Store Connect 제출 준비

- 최종 확인일: 2026-08-13

## 목표

App Store 심사에 필요한 Apple Developer 설정, 앱 레코드, 개인정보·법적 선언, 메타데이터와 심사 자료를 누락 없이 준비한다.

이 문서는 기능 구현이 끝난 뒤 급하게 입력하는 목록이 아니라, TestFlight 전에 확정해야 할 운영 체크리스트다.

## 현재 상태와 선행 조건

- Apple Developer Program의 유료 멤버십이 필요하며, 프로젝트의 Team은 실제 배포 Team으로 확정해야 한다.
- Team 값이 비어 있거나 개인 Team이면 배포 서명과 capability가 정상 구성되지 않는다.
- 실제 Team ID, 인증서, 프로비저닝 프로파일 같은 값은 문서나 저장소에 비밀값으로 기록하지 않는다.
- Apple 로그인과 Associated Domains 등 capability를 사용하는 기능은 App ID와 Xcode 양쪽 설정이 일치해야 한다.
- Associated Domains 상세 점검: [`ios/app-store-readiness/06-associated-domains/README.md`](../06-associated-domains/README.md)
- 기존 배포 체크리스트: [`ios/DEPLOYMENT_CHECKLIST.md`](../../DEPLOYMENT_CHECKLIST.md)

## 1. Apple Developer Program

- [ ] 배포 주체가 개인인지 조직인지 확정한다.
- [ ] Apple Developer Program 유료 등록을 완료한다.
- [ ] 계약, 세금, 은행 정보가 필요한 경우 담당자를 정한다.
- [ ] Account Holder, Admin, App Manager 등 최소 권한 역할을 배정한다.
- [ ] 법인명·판매자 이름과 멤버십 갱신 담당자를 확인한다.

조직 계정은 D-U-N-S 정보와 법적 실체 확인 때문에 등록에 시간이 걸릴 수 있으므로 제출 직전에 시작하지 않는다.

## 2. App ID와 capability

- [ ] 운영 Bundle ID와 일치하는 Explicit App ID를 생성한다.
- [ ] Xcode의 Signing & Capabilities에서 실제 Team을 선택한다.
- [ ] 자동 서명을 사용할지 수동 서명을 사용할지 팀 기준을 정한다.
- [ ] Sign in with Apple capability를 활성화한다.
- [ ] Push Notifications capability를 활성화한다.
- [ ] Associated Domains capability를 활성화한다.
- [ ] App ID와 provisioning profile에 capability가 반영되었는지 확인한다.
- [ ] Release archive의 entitlements를 검사한다.

개발용과 운영용 식별자를 분리한다면 App ID, APNs 환경, 서버 설정도 함께 분리해야 한다.

## 3. App Store Connect 앱 레코드

- [ ] App Store Connect에서 새 앱 레코드를 만든다.
- [ ] 플랫폼으로 iOS를 선택한다.
- [ ] 앱 이름과 기본 언어를 확정한다.
- [ ] 운영 Bundle ID를 연결한다.
- [ ] SKU를 팀 규칙에 맞게 정한다.
- [ ] 사용자 접근 권한과 기본·보조 카테고리를 지정한다.

앱 이름은 상표·중복·검색 노출을 고려하고, 웹 서비스에서 사용하는 표기와 일관되게 유지한다.

## 4. 버전과 빌드 관리

- [ ] 마케팅 버전 `CFBundleShortVersionString`을 확정한다.
- [ ] 빌드 번호 `CFBundleVersion`을 업로드마다 증가시킨다.
- [ ] Release 구성으로 Archive한다.
- [ ] Archive에 개발용 endpoint나 mock flag가 포함되지 않았는지 확인한다.
- [ ] TestFlight 내부 테스트를 먼저 진행한다.
- [ ] 최종 심사에 연결할 빌드를 명시적으로 선택한다.
- [ ] 제출한 소스 커밋과 App Store 빌드 번호를 추적 가능하게 기록한다.

동일 버전에 여러 빌드를 올릴 수 있지만 같은 빌드 번호는 다시 업로드할 수 없다.

## 5. 연령 등급과 콘텐츠 선언

- [ ] App Store Connect의 연령 등급 질문에 실제 기능 기준으로 답한다.
- [ ] 사용자 생성 콘텐츠, 메시지·공유 기능의 존재를 반영한다.
- [ ] 의료·건강 기능으로 오해될 표현이 없는지 확인한다.
- [ ] 부적절한 콘텐츠 신고·차단·관리 수단을 검토한다.
- [ ] 암호화 사용 여부와 수출 규정 질문에 답한다.

서드파티 SDK와 HTTPS 통신도 수출 규정 응답에 영향을 줄 수 있으므로 코드와 의존성을 기준으로 판단한다.

## 6. App Privacy

- [x] 서버·iOS 데이터 inventory 초안을 [개인정보·AI 상세 문서](../03-privacy-and-ai-consent/README.md)에 정리했다.
- [x] Name, Email, Photos or Videos, Other User Content, User ID, Device ID와 Other Data Types를 현재 `PrivacyInfo.xcprivacy`에 App Functionality·Linked to User·non-tracking으로 선언했다.
- [x] 별도 광고·analytics·crash SDK가 없는 현재 상태와 서버 운영 로그 범위를 구분했다.
- [ ] Release Archive Privacy Report와 실제 포함 SDK를 inventory·manifest와 대조한다.
- [ ] App Store Connect에서 각 데이터 유형, App Functionality, Linked to User와 non-tracking 답변을 실제 Release 기준으로 최종 확인하고 Publish한다.
- [ ] 개인정보 처리방침 URL을 운영 URL로 입력한다.
- [x] 저장소의 `PRIVACY 2026-08-13` 정책 내용과 App Privacy 입력 초안을 기술 데이터 흐름 기준으로 일치시켰다.
- [!] 법률·운영 계약 검토와 Google paid service/DPA 확인은 저장소 기술 정합성 완료와 별개의 출시 차단 항목이다.

“수집하지 않음”은 앱 또는 서버가 실제로 데이터를 받지 않는 경우에만 선택한다.

## 7. DSA와 규제 정보

- [ ] EU 배포 여부를 결정한다.
- [ ] EU에 배포한다면 Digital Services Act의 trader 여부를 선언한다.
- [ ] trader라면 Apple이 요구하는 주소, 전화번호, 이메일 검증을 완료한다.
- [ ] 표시되는 사업자 정보가 실제 운영 주체와 일치하는지 확인한다.
- [ ] 지역별 배포 제한이 필요한지 검토한다.

법적 지위 판단이 애매하면 임의로 선택하지 말고 사업자 또는 법률 담당자와 확인한다.

## 8. 5개 언어 메타데이터

Dutypark가 지원하는 `ko`, `en`, `ja`, `zh`, `es` 기준으로 Store 메타데이터를 준비한다.

- [ ] 앱 이름, 부제, 설명, 키워드
- [ ] 프로모션 텍스트와 새로운 기능(What's New)
- [ ] 지원 URL, 개인정보 처리방침 URL, 사용하는 경우 마케팅 URL

기계 번역만 붙여 넣지 말고 기능명, 일정·근무 용어, 개인정보 표현을 각 언어에서 검수한다.

## 9. 스크린샷과 미리보기

- [ ] App Store Connect가 요구하는 기기 크기별 스크린샷을 준비한다.
- [ ] 실제 앱 UI와 실제 테스트 데이터로 촬영한다.
- [ ] 이름, 이메일, 일정 등 개인정보가 노출되지 않도록 전용 데이터를 사용한다.
- [ ] mockup이 실제 기능처럼 오해되지 않게 하고, 5개 언어별 현지화 범위를 명확히 한다.
- [ ] 다크 모드만으로 기능을 숨기지 않고 대표 화면을 균형 있게 보여준다.
- [ ] 로그인, 캘린더, Todo, 협업 등 핵심 흐름을 포함한다.

실제 테스트 데이터는 심사 중 동일하게 재현할 수 있도록 유지하되 운영 사용자의 정보를 복사하지 않는다.

## 10. 지원 URL과 심사 연락처

- [ ] 로그인 없이 접근 가능한 지원 페이지를 운영한다.
- [ ] 지원 페이지에 문의 방법과 개인정보 처리방침 링크를 제공한다.
- [ ] 삭제되거나 리다이렉트가 반복되는 URL을 사용하지 않는다.
- [ ] App Review 연락 담당자의 이름, 이메일, 전화번호를 최신 상태로 둔다.
- [ ] 심사 기간 중 담당자가 연락을 받을 수 있게 한다.

## 11. 심사 계정과 Review Notes

- [ ] 심사용 전용 계정을 만든다.
- [ ] 계정이 잠기거나 만료되지 않게 하고, 2단계 인증 등이 있다면 심사 가능한 절차를 제공한다.
- [ ] 공유·친구·팀 기능 확인에 보조 계정이 필요하면 함께 제공한다.
- [ ] 로그인 ID와 비밀번호를 App Store Connect의 전용 필드에만 입력한다.
- [ ] 관리자 전용 또는 조건부 기능의 진입 방법을 Review Notes에 쓴다.
- [ ] Apple 로그인, 알림, 위치 등 권한 요청 목적을 간단히 설명한다.
- [ ] 백엔드가 심사 기간 동안 운영 상태인지 확인한다.

실제 운영자 계정이나 개인 계정을 심사 계정으로 제공하지 않는다.

## 제출 전 완료 조건

- [ ] 유료 Apple Developer Program 멤버십과 계약 상태가 유효하다.
- [ ] 실제 Team, Explicit App ID, Bundle ID, capability가 모두 일치한다.
- [ ] App Store Connect 앱 레코드와 제출 버전·빌드가 연결되어 있다.
- [ ] 카테고리, 연령 등급, 수출 규정, DSA 선언을 완료했다.
- [ ] App Privacy가 실제 서버·앱 동작 및 개인정보 처리방침과 일치한다.
- [ ] 5개 언어 메타데이터와 실제 테스트 데이터 스크린샷을 검수했다.
- [ ] 지원 URL과 개인정보 처리방침 URL이 로그인 없이 열린다.
- [ ] 심사 계정과 보조 계정으로 핵심 기능을 재현할 수 있다.
- [ ] Review Notes에 특수 진입 방법과 심사에 필요한 설명을 남겼다.
- [ ] TestFlight에서 최종 빌드의 로그인, 푸시, 링크, CRUD 흐름을 확인했다.

## 공식 문서

- [Apple Developer Program enrollment](https://developer.apple.com/programs/enroll/)
- [Apple: Register an App ID](https://developer.apple.com/help/account/identifiers/register-an-app-id/)
- [App Store Connect: Add a new app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/)
- [App Store Connect: Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
- [App Store Connect: Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [App Store Connect: Set an app age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/)
- [App Store Connect: Digital Services Act trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
