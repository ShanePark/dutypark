# App Store Connect 입력 준비

## 현재 상태

- Apple Developer Program 멤버십, Team ID `2V47G42CDS`와 운영 Bundle ID `io.github.shanepark.dutypark`는 확정돼 있다.
- App Store Connect에 `Dutypark` iOS 앱 레코드를 생성했으며 버전 `1.0`이 `Prepare for Submission` 상태인 것을 2026-08-14 화면에서 확인했다.
- 2026-08-15 Xcode에서 `Dutypark` 1.0 (1)의 App Store Connect 업로드 완료를 확인했다. Connect의 처리 완료와 빌드 표시 여부는 아직 확인하지 않았다.
- App Store Connect가 EU 배포 전 trader status 제공 필요 경고를 표시하고 있다. EU 판매 범위와 DSA trader 여부는 아직 확정하지 않았다.
- 앱과 서버의 개인정보 데이터 inventory 및 수출 규정 기술 근거는 별도 상세 문서에 정리돼 있다.
- 이 문서는 App Store Connect에 아직 입력·공개·확정해야 하는 정보만 관리한다. 빌드 서명·업로드는 [릴리스 엔지니어링](../11-release-engineering/README.md), TestFlight와 심사 실행은 [TestFlight 및 App Review](../08-testflight-and-review/README.md)를 따른다.

## 남은 체크

### 앱 레코드와 판매 범위

- [x] iOS 앱 레코드를 생성하고 Bundle ID `io.github.shanepark.dutypark`를 연결한다.
- [ ] 앱 이름, 기본 언어, SKU, 기본·보조 카테고리와 사용자 접근 권한을 확정한다.
- [ ] 판매 국가·지역과 EU 배포 여부를 정한다.
- [ ] App Store Connect에 표시된 trader status 경고를 확인하고, EU 배포 시 DSA trader 여부를 판단해 필요한 연락처·주소 검증을 완료한다.
- [ ] 개인 계정의 판매자명이 계정 소유자의 법적 실명으로 표시되는 점과 멤버십 갱신 책임을 확인한다.
- [ ] 계약, 세금·은행 정보가 실제 판매 방식에 필요하면 완료한다.

### App Privacy와 규제 응답

- [ ] 최종 Release Privacy Report와 포함 SDK를 [개인정보·AI 상세 문서](../03-privacy-and-ai-consent/README.md), [PrivacyInfo.xcprivacy](../../Dutypark/PrivacyInfo.xcprivacy)와 대조한다.
- [ ] 실제 수집 데이터, 사용 목적, 사용자 연결 여부와 non-tracking 상태를 App Privacy에 입력해 Publish한다.
- [ ] 로그인 없이 열리는 개인정보 처리방침 URL을 입력한다.
- [ ] 연령 등급 질문에 사용자 생성 콘텐츠와 공유·협업 기능을 반영한다.
- [ ] 콘텐츠 권리와 광고 식별자 관련 질문에 최종 빌드 기준으로 답한다.
- [ ] 수출 규정 질문은 [릴리스 엔지니어링 문서](../11-release-engineering/README.md)의 최종 Archive 검증 결과와 다시 대조해 입력한다.
- [ ] 사용자 생성 콘텐츠에 필요한 신고·차단·운영 대응이 완료된 뒤 해당 기능을 사실대로 선언한다.

### 한국어·영어 메타데이터

- [ ] `ko`, `en`의 앱 이름, 부제, 설명, 키워드와 프로모션 텍스트를 작성·검수한다.
- [ ] 제출 버전에 맞는 `What's New`를 작성한다.
- [ ] 로그인 없이 열리는 지원 URL과, 사용하는 경우 마케팅 URL을 입력한다.
- [ ] App Store가 요구하는 기기 크기별 스크린샷을 실제 UI와 전용 테스트 데이터로 준비한다.
- [ ] 스크린샷과 설명이 현재 기능을 과장하지 않고 개인정보를 노출하지 않는지 검수한다.

### 심사 정보

- [ ] 실제 응답 가능한 App Review 연락 담당자의 이름, 이메일과 전화번호를 입력한다.
- [ ] 심사 기간에 유지할 전용 계정과 팀·친구 기능용 보조 계정을 준비한다.
- [ ] 계정 자격 증명은 App Store Connect 전용 보안 필드에만 입력한다.
- [ ] Review Notes에 로그인, 소셜·Apple 로그인, 회원 탈퇴, 권한 요청, 푸시, Universal Link와 조건부 기능의 재현 절차를 작성한다.
- [ ] AI 선택 동의, 외부 AI 처리업체로 전송되는 데이터, 동의 철회와 수동 입력 경로를 실제 운영 정책에 맞게 설명한다. 특정 공급자 정보는 앱 구현에 고정하지 않고 current 개인정보 처리방침과 일치시킨다.

## 완료 조건

- 앱 레코드, 판매 범위, 카테고리와 규제 선언이 확정돼 있다.
- App Privacy와 개인정보 처리방침이 최종 앱·서버 동작과 일치한다.
- 한국어·영어 메타데이터, 스크린샷과 공개 URL이 검수돼 있다.
- 심사 담당자, 전용 계정과 Review Notes만으로 주요 기능을 재현할 수 있다.
- 제출할 빌드와 버전이 App Store Connect 앱 레코드에 연결돼 있다.

## 불변 계약

- 앱 이름, 설명, 스크린샷과 Privacy 응답은 실제 출시 빌드를 과장하거나 축소해서는 안 된다.
- 실제 운영자·사용자 계정과 데이터는 심사 자료에 사용하지 않는다.
- 비밀번호, OAuth secret, APNs 키와 관리자 자격 증명을 문서나 Review Notes에 기록하지 않는다.
- 지원 URL과 개인정보 처리방침 URL은 로그인 없이 공개 접근 가능해야 한다.
- 법적·계약상 판단이 필요한 항목은 기술 추정만으로 완료 처리하지 않는다.

## 필요한 실행 및 참고

- 개인정보·AI: [03-privacy-and-ai-consent/README.md](../03-privacy-and-ai-consent/README.md)
- 사용자 생성 콘텐츠: [10-user-generated-content/README.md](../10-user-generated-content/README.md)
- 릴리스 엔지니어링: [11-release-engineering/README.md](../11-release-engineering/README.md)
- [App Store Connect: Add a new app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/)
- [App Store Connect: Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [App Store Connect: Set an app age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/)
- [App Store Connect: DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)
- [Apple: Provide App Review information](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/provide-app-review-information/)
