# Dutypark iOS 배포 체크리스트

최종 확인일: 2026-08-13

이 문서는 현재 저장소와 운영 주소 `https://dutypark.o-r.kr`를 기준으로, 실제 배포 전 필요한 작업을 순서대로 정리한다. 비밀값은 저장소나 이 문서에 기록하지 않는다.

상태 표기:

- `[x]` 저장소에서 확인된 완료 항목
- `[ ]` 아직 필요한 항목
- `[!]` 사용자 결정 또는 운영 서비스 영향 확인이 먼저 필요한 항목

## 0. 현재 상태 요약

- `[x]` iOS Bundle ID가 `com.tistory.shanepark.dutypark`로 설정되어 있다.
- `[x]` Debug/Release의 APNs 환경, Push Notifications 및 Associated Domains entitlement가 저장소에 있다.
- `[x]` 앱은 운영 API `https://dutypark.o-r.kr/api/`를 사용한다.
- `[x]` 카카오·네이버용 모바일 OAuth 서버 경로와 앱 복귀 스킴 `dutypark://oauth/callback`이 구현되어 있다.
- `[x]` APNs 등록·해제 및 발송 코드와 배포 설정 자리만 마련되어 있다.
- `[x]` 앱 내 약관·개인정보 처리방침 조회 화면과 `PrivacyInfo.xcprivacy`가 있다.
- `[ ]` 유료 Apple Developer Program 가입 및 배포 Team 확정은 확인되지 않았다. 현재 Personal Team 설치는 App Store 배포 준비 완료를 뜻하지 않는다.
- `[ ]` App ID, 배포 인증서/프로비저닝, APNs 키 및 App Store Connect 앱 레코드는 외부 콘솔에서 완료해야 한다.
- `[ ]` 카카오·네이버 콘솔에 모바일 콜백을 추가하고, 해당 서버 코드를 운영에 배포해야 한다.
- `[ ]` Sign in with Apple은 아직 구현되어 있지 않다.
- `[!]` 현재 앱의 회원 탈퇴는 관리자 문의 안내뿐이다. Apple 심사 기준의 앱 내 계정 삭제 기능을 충족하지 않으므로 서버·웹 동시 영향 범위를 합의한 후 구현해야 한다.
- `[ ]` 운영 서버의 AASA(`apple-app-site-association`) 파일이 아직 올바른 JSON으로 제공되지 않는다.
- `[ ]` TestFlight 업로드와 심사 정보 입력은 아직 수행하지 않았다.

## 1. Apple Developer Program과 배포 Team

### 사용자가 할 일

- `[ ]` [Apple Developer Program](https://developer.apple.com/programs/enroll/) 유료 멤버십에 개인 또는 조직으로 가입한다. Apple Account의 2단계 인증과 정확한 법적 이름·주소·전화번호가 필요하다.
- `[ ]` 가입 완료 후 Apple Developer의 **Membership details**에서 다음 두 값을 확인한다.
  - Team Name
  - Team ID
- `[ ]` 개인 가입이면 법적 이름이 App Store 판매자명으로 표시됨을 확인한다. 조직명 노출이 필요하면 조직 가입 요건을 먼저 검토한다.
- `[ ]` 최신 계약이 표시되면 Account Holder가 동의한다.

### Codex가 저장소에서 할 일

- `[ ]` 사용자가 Team ID를 확인한 뒤 Xcode 프로젝트의 Signing Team을 해당 유료 Team으로 지정한다.
- `[ ]` 유료 Team으로 기기용 Release 빌드와 Archive가 서명되는지 검증한다.

참고: [Apple Developer Program 등록](https://developer.apple.com/help/account/membership/enrolling-in-the-app), [App Store Connect 흐름](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow)

## 2. Explicit App ID와 필수 Capability

### 사용자가 할 일

- `[ ]` Apple Developer의 **Certificates, Identifiers & Profiles > Identifiers > + > App IDs > App**에서 Explicit App ID를 등록한다.
  - Description: 사용자가 알아보기 쉬운 Dutypark 명칭
  - Bundle ID: `com.tistory.shanepark.dutypark`
- `[ ]` 해당 App ID에서 다음 capability를 활성화한다.
  - Push Notifications
  - Associated Domains
  - Sign in with Apple — 6단계 구현을 진행할 때 Primary App ID로 설정
- `[ ]` Xcode 자동 서명을 사용할지, 수동으로 Development/Distribution 인증서와 프로비저닝 프로파일을 관리할지 결정한다. 이 프로젝트는 단일 앱이므로 우선 Xcode 자동 서명이 가장 단순하다.

### Codex가 저장소에서 할 일

- `[x]` Bundle ID를 `com.tistory.shanepark.dutypark`로 고정했다.
- `[x]` `aps-environment`와 `applinks:dutypark.o-r.kr` entitlement를 추가했다.
- `[ ]` Sign in with Apple 구현 시 해당 entitlement와 프레임워크를 추가한다.
- `[ ]` 최종 배포 Team에서 Debug는 development APNs, Release는 production APNs entitlement로 서명되는지 확인한다.

App ID의 capability를 변경하면 기존 프로비저닝 프로파일이 무효화될 수 있으므로, 변경 후 프로파일을 다시 생성하거나 Xcode 자동 서명이 갱신하도록 한다.

참고: [App ID 등록](https://developer.apple.com/help/account/identifiers/register-an-app-id), [Capability 활성화](https://developer.apple.com/help/account/identifiers/enable-app-capabilities/)

## 3. APNs 푸시 알림

### 사용자가 할 일

- `[ ]` Apple Developer의 **Certificates, Identifiers & Profiles > Keys > +**에서 APNs 사용이 허용된 키를 생성한다.
- `[ ]` 생성 직후 `.p8` 파일을 안전한 비밀 저장소에 보관한다. Apple은 같은 키 파일을 다시 내려받게 해주지 않는다.
- `[ ]` 다음 값을 확인해 운영 배포의 비밀 설정에 입력한다.
  - Team ID
  - APNs Key ID
  - `.p8` 개인 키 원문
- `[ ]` 이 값들을 Git, 문서, 이슈, 채팅 또는 앱 번들에 넣지 않는다.

### Codex가 저장소에서 할 일

- `[x]` 빈 값이면 APNs 발송이 비활성화되는 안전한 서버 기본값과 배포 변수 연결을 추가했다.
- `[x]` 앱의 기기 토큰 등록·해제 및 서버 발송 코드가 있다.
- `[!]` APNs 설치 정보를 회원이 아니라 로그인 갱신 세션에 묶는 마이그레이션은 운영 데이터 영향 승인을 받은 뒤 마무리한다.
- `[ ]` 운영 비밀 설정이 주입된 뒤 sandbox 기기 토큰과 TestFlight production 기기 토큰을 각각 실기기에서 검증한다.

참고: [서비스용 개인 키 생성](https://developer.apple.com/help/account/keys/create-a-private-key), [Push Notifications 활성화](https://developer.apple.com/help/account/identifiers/enable-app-capabilities/)

## 4. App Store Connect 앱 레코드

### 사용자가 할 일

- `[ ]` App Store Connect에서 **Apps > + > New App**을 선택한다.
  - Platform: iOS
  - Name: 출시할 앱 이름
  - Primary Language: 기본 스토어 언어
  - Bundle ID: `com.tistory.shanepark.dutypark`
  - SKU: 사용자가 정한 내부 관리용 고유 문자열
  - User Access: 팀 운영 방식에 맞게 선택
- `[ ]` 앱 이름, 부제, 설명, 키워드, 카테고리, 연령 등급, 지원 URL, 저작권, 출시 국가와 가격을 입력한다.
- `[ ]` 실제 앱 화면만 사용한 App Store 스크린샷을 준비한다. 실제 사용자 개인정보 대신 테스트 데이터를 사용한다.
- `[ ]` App Review 연락처와 전체 기능을 확인할 수 있는 심사용 계정을 준비한다.

### Codex가 저장소에서 할 일

- `[x]` 버전 `1.0`, 빌드 `1` 및 비면제 암호화 미사용 선언의 프로젝트 기본값이 있다.
- `[ ]` 제출 시점에 마케팅 버전·빌드 번호, 앱 아이콘, 표시 이름 및 Archive 내용을 최종 점검한다.
- `[ ]` iPhone 13 mini와 iPhone 16 Pro 중심으로 실기기 회귀 테스트를 완료한다.

앱 레코드는 빌드를 업로드하기 전에 먼저 만들어야 하며, Account Holder가 최신 계약에 동의하지 않으면 생성할 수 없다.

참고: [새 앱 레코드 추가](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/), [앱 정보 필드](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)

## 5. 카카오·네이버 로그인 콘솔

현재 구현은 Kakao/Naver iOS SDK를 앱에 추가하지 않고, `ASWebAuthenticationSession`에서 기존 서버 OAuth를 사용하는 방식이다. 따라서 앱에 제공자 Client Secret을 넣지 않으며, 운영용으로는 제공자 콘솔에 아래 HTTPS 콜백을 추가한다. Debug 시뮬레이터는 로컬 백엔드를 사용하므로 로컬 OAuth까지 시험할 때만 `http://localhost:8080/api/auth/mobile/oauth/callback/{provider}`도 해당 제공자 콘솔에 별도로 등록해야 한다.

### 카카오 — 사용자가 할 일

- `[ ]` Kakao Developers의 기존 Dutypark 앱에서 **Kakao Login** 사용 설정이 ON인지 확인한다.
- `[ ]` **App > Platform key > REST API key > Redirect URI**에 아래 값을 정확히 추가한다.
  - `https://dutypark.o-r.kr/api/auth/mobile/oauth/callback/kakao`
- `[ ]` Debug 시뮬레이터에서 로컬 백엔드로 로그인할 때만 아래 값도 추가한다.
  - `http://localhost:8080/api/auth/mobile/oauth/callback/kakao`
- `[!]` 기존 웹 콜백 `https://dutypark.o-r.kr/api/auth/Oauth2ClientCallback/kakao`를 삭제하거나 바꾸지 않는다.
- `[!]` **Kakao Client Secret을 지금 새로 활성화하지 않는다.** 현재 웹과 모바일 서버의 카카오 토큰 요청은 Client Secret을 보내지 않는다. 콘솔에서 이를 활성화하면 서버 코드를 함께 수정·배포하기 전까지 기존 웹 로그인과 앱 로그인이 모두 실패할 수 있다.
- `[ ]` 카카오 동의 항목과 앱 검수 상태가 현재 운영 정책에 맞는지 확인한다.

### 네이버 — 사용자가 할 일

- `[ ]` Naver Developers의 기존 Dutypark 애플리케이션에서 **API 설정 > 로그인 오픈 API 서비스 환경**의 PC Web 또는 Mobile Web Callback URL 목록에 아래 값을 정확히 추가한다. 두 슬롯의 검증 방식은 같으며, HTTPS 서버 콜백이므로 iOS SDK용 URL Scheme 설정은 사용하지 않는다.
  - `https://dutypark.o-r.kr/api/auth/mobile/oauth/callback/naver`
- `[ ]` Debug 시뮬레이터에서 로컬 백엔드로 로그인할 때만 아래 값도 추가한다.
  - `http://localhost:8080/api/auth/mobile/oauth/callback/naver`
- `[!]` 기존 웹 콜백 `https://dutypark.o-r.kr/api/auth/Oauth2ClientCallback/naver`를 삭제하거나 바꾸지 않는다. 네이버는 콜백을 여러 개 등록할 수 있으므로 새 값을 추가한다.
- `[!]` 기존 Naver Client ID/Client Secret을 임의로 재발급하거나 교체하지 않는다. 교체 시 운영 서버 설정을 같은 배포에서 갱신하지 않으면 기존 웹 로그인과 앱 로그인이 모두 실패한다.
- `[ ]` 제공 정보, 서비스 URL, 검수 상태가 현재 운영 정책에 맞는지 확인한다.

### Codex가 저장소와 서버에서 할 일

- `[x]` 두 모바일 콜백, `state`, 일회용 교환 코드와 PKCE 기반 앱 복귀 흐름을 구현했다.
- `[x]` 제공자 비밀값은 앱에 포함하지 않고 서버에서만 사용한다.
- `[ ]` 운영 서버의 `KAKAO_REST_API_KEY`, `NAVER_CLIENT_ID`, `NAVER_CLIENT_SECRET`이 각 콘솔의 기존 Dutypark 앱 값과 일치하는지 확인한다.
- `[ ]` 모바일 OAuth 서버 변경을 운영에 배포한다. 콘솔 콜백 추가와 서버 배포가 모두 끝나야 실앱 로그인이 성공한다.
- `[ ]` 배포 직후 기존 웹 카카오·네이버 로그인과 앱 카카오·네이버 로그인을 각각 확인한다.

참고: [Kakao Login 사전 설정](https://developers.kakao.com/docs/en/kakaologin/prerequisite), [Kakao Redirect URI 설명](https://developers.kakao.com/docs/en/kakaologin/faq), [Naver Callback URL](https://help.naver.com/service/23029/contents/17439), [Naver 복수 Callback 안내](https://help.naver.com/service/23029/contents/20552)

## 6. Sign in with Apple

Dutypark는 카카오·네이버로 주 계정을 만들거나 인증할 수 있다. Apple의 로그인 서비스 심사 기준 4.8을 가장 예측 가능하게 충족하려면 Sign in with Apple을 동등한 로그인·가입·계정 연결 수단으로 제공해야 한다.

### 사용자가 할 일

- `[ ]` 2단계의 App ID에서 **Sign in with Apple**을 Primary로 활성화한다.
- `[ ]` 서버 측 토큰 처리와 연결 해제에 필요한 Apple 설정·키를 생성할 때 Team ID, Key ID 등 식별값을 확인하고 개인 키는 비밀 저장소에만 보관한다.
- `[ ]` 사용자가 이메일 가리기를 선택해도 가입과 로그인이 동작하는 정책을 승인한다.

### Codex가 저장소에서 할 일

- `[ ]` iOS 로그인·가입·설정의 계정 연결 화면에 Sign in with Apple을 추가한다.
- `[ ]` 서버에서 Apple identity token의 서명, issuer, audience, nonce를 검증하고 기존 계정 생성·연결·해제 정책에 맞춘다.
- `[ ]` Apple이 이름·이메일을 최초 승인에만 제공하는 경우와 Private Relay 이메일을 처리한다.
- `[ ]` 카카오·네이버와 동일한 수준으로 가입 동의, 중복 연결, 로그인, 로그아웃 및 테스트를 추가한다.

참고: [Sign in with Apple 개요](https://developer.apple.com/help/account/capabilities/about-sign-in-with-apple), [App Review Guideline 4.8](https://developer.apple.com/app-store/review/guidelines/#login-services)

## 7. 앱 내 회원 탈퇴

### 저장소 구현 상태

- `[x]` iOS 설정에서 안전한 재인증, 팀 이관, 이름 확인과 최종 확인을 거쳐 계정 삭제를 요청할 수 있다.
- `[x]` 서버는 요청 즉시 계정을 `DELETION_PENDING`으로 전환하고 refresh session·연결된 push 정보를 무효화한 뒤 durable 비동기 job으로 파일·DB를 정리한다.
- `[x]` 1인 팀 삭제, 다인 팀 관리자 이관과 공동 TEAM 데이터·첨부의 보존·이관 규칙을 구현했다.
- `[x]` `PRIVACY`와 `TERMS` 2026-08-13 버전에 즉시 접근 차단, 비동기 삭제와 공동 데이터 예외를 실제 흐름대로 반영했다.

### 출시 전 남은 일

- `[ ]` 실제 MySQL 또는 운영 유사 환경에서 locking, 전체 삭제와 재시도를 검증한다.
- `[ ]` Kakao·Naver provider-side revoke를 구현·검증하고 Sign in with Apple 도입 시 Apple revoke를 추가한다.
- `[ ]` TestFlight 실기기에서 삭제 요청과 재가입 흐름을 확인하고 Review Notes에 메뉴 경로·비동기 처리·확인 절차를 기록한다.
- `[ ]` 법적 보존 의무, 감사 로그 보유 범위와 운영 모니터링 책임자를 최종 확정한다.

참고: [App Review Guideline 5.1.1(v)](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage)

## 8. 개인정보 처리방침과 App Privacy

### 사용자가 할 일

- `[ ]` 운영 개인정보 처리방침이 앱에서 수집·처리하는 계정 정보, 사용자 콘텐츠, 첨부파일, 소셜 로그인 식별자, 알림 토큰 및 진단 데이터를 정확히 설명하는지 법적 관점에서 확인한다.
- `[ ]` App Store Connect의 Privacy Policy URL에 `https://dutypark.o-r.kr/privacy`를 입력한다.
- `[ ]` App Privacy 질문에서 앱과 연결된 서버 및 제3자 서비스가 수집하는 모든 데이터 유형, 목적, 사용자 연결 여부와 추적 여부를 사실대로 신고하고 Publish한다.
- `[ ]` 지원 URL과 개인정보 선택/삭제 안내 URL을 공개 접근 가능한 주소로 정한다.

### Codex가 저장소에서 할 일

- `[x]` 앱 안에서 개인정보 처리방침을 열 수 있다.
- `[x]` `V2.2.28`의 `PRIVACY 2026-08-13`에 HttpOnly cookie, 기기 저장소, push, 첨부, Kakao/Naver, Google AI, 보유·삭제와 공동 TEAM 예외를 실제 기술 흐름대로 반영하고 migration test 2/2를 통과했다.
- `[x]` `V2.2.29`에 `TERMS`와 `AI_SCHEDULE_PARSING` 2026-08-13 정책을 추가하고 별도 선택 동의 event/API, owner 기준 schedule gate와 worker 외부 호출 직전 재검사를 구현했다.
- `[x]` `PrivacyInfo.xcprivacy`에 UserDefaults required-reason API와 Name, Email, Photos or Videos, Other User Content, User ID, Device ID, Other Data Types를 App Functionality·Linked to User·non-tracking으로 선언했다.
- `[x]` 회원 탈퇴 구현 뒤 개인정보 처리방침·이용약관과 manifest 데이터 유형을 다시 점검했다.
- `[!]` Google AI는 Cloud Billing이 활성화된 paid service와 DPA 적용 Cloud Project를 확인하기 전 production에서 사용하지 않고 unpaid service에는 일정 데이터를 전송하지 않는다.
- `[ ]` 운영 개인정보 처리방침을 법적 관점에서 최종 검토하고 Google의 실제 처리 국가·하위처리자·보관 조건 및 법정 보존 의무를 확정한다.
- `[ ]` Xcode Release Archive의 Privacy Report와 실제 포함 SDK를 `PrivacyInfo.xcprivacy` 및 App Store Connect 입력값과 대조한다.
- `[ ]` App Store Connect의 Privacy Policy URL과 App Privacy 답변을 입력하고 Publish한다.
- `[ ]` Sign in with Apple 또는 새 SDK를 추가하면 정책, manifest와 App Privacy를 다시 점검한다.

App Store Connect의 “앱이 데이터를 수집하지 않음”은 서버에 계정·일정·할 일·첨부파일 등이 저장되는 Dutypark에는 맞지 않는다.

참고: [App Privacy 관리](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy), [Privacy manifest](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)

## 9. AASA와 Universal Links

### 사용자가 할 일

- `[ ]` 유료 Apple Team ID를 Codex에 전달한다. Team ID는 비밀키가 아니지만 App ID 구성에 정확히 일치해야 한다.

### Codex가 저장소와 서버에서 할 일

- `[x]` 앱 entitlement에 `applinks:dutypark.o-r.kr`를 추가했다.
- `[x]` 앱은 `https://dutypark.o-r.kr`의 가이드, 약관, 개인정보, 공개 근무표 및 주요 앱 경로를 해석한다.
- `[ ]` Team ID를 받은 뒤 AASA의 앱 식별자를 `{Team ID}.com.tistory.shanepark.dutypark` 형식으로 확정하고 필요한 경로만 허용한다.
- `[ ]` `https://dutypark.o-r.kr/.well-known/apple-app-site-association`에서 확장자 없는 JSON을 HTTPS, 유효한 인증서, 리다이렉트 없이 올바른 Content-Type으로 제공한다.
- `[!]` 이 작업은 운영 정적 파일/프록시 설정에 영향을 주므로 배포 전에 사용자와 변경 내용을 확인한다.
- `[ ]` Apple CDN 반영 시간을 고려해 설치 직후 및 재설치 후 실제 링크 열기를 검증한다.

현재 해당 경로는 SPA HTML로 처리되므로 Universal Links 검증을 통과하지 못한다.

참고: [Associated Domains 지원](https://developer.apple.com/documentation/xcode/supporting-associated-domains), [Universal Links 지원](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app)

## 10. TestFlight부터 App Review까지

### Codex가 준비할 일

- `[ ]` Release Archive를 생성하고 서명, entitlement, privacy manifest, 아이콘, 버전·빌드 번호를 검증한다.
- `[ ]` 운영 API에서 이메일, 카카오, 네이버, Apple 로그인과 주요 기능을 회귀 테스트한다.
- `[ ]` iPhone 13 mini와 iPhone 16 Pro에서 라이트·다크 모드, 한국어·영어 및 알림을 최종 확인한다.
- `[ ]` 빌드를 App Store Connect에 업로드한다.

### 사용자가 할 일

- `[ ]` App Store Connect의 TestFlight에 Beta App Description, 테스트 항목, 피드백 이메일, 심사 연락처와 로그인 정보를 입력한다.
- `[ ]` 먼저 내부 테스터에게 배포하고 주요 기능을 확인한다.
- `[ ]` 필요하면 외부 테스트 그룹을 만들고 Beta App Review를 통과한 뒤 초대한다.
- `[ ]` App Store 제품 페이지 정보, App Privacy, 연령 등급, 수출 규정, 콘텐츠 권리와 심사 노트를 최종 확인한다.
- `[ ]` 심사 계정이 전체 기능에 접근 가능하고 심사 기간 내내 운영 서버가 켜져 있는지 확인한다.
- `[ ]` 빌드를 App Review에 제출하고 출시 방식을 선택한다.

참고: [빌드 업로드](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/), [TestFlight 개요](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/), [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

## 권장 실행 순서

1. 유료 Apple Developer Program 가입 및 Team ID 확정
2. Explicit App ID와 Push/Associated Domains/Sign in with Apple capability 구성
3. App Store Connect 앱 레코드 생성
4. 카카오·네이버 모바일 콜백을 기존 웹 콜백 옆에 추가
5. 모바일 OAuth 서버 변경 운영 배포 후 웹·앱 로그인 동시 검증
6. Sign in with Apple 구현 및 검증
7. 회원 탈퇴 정책 합의 후 서버·웹·앱 구현
8. APNs 키를 운영 비밀 설정에 주입하고 sandbox/production 푸시 검증
9. Team ID 기반 AASA 배포 및 Universal Links 검증
10. 개인정보 처리방침·App Privacy·스토어 메타데이터 확정
11. Archive 업로드, TestFlight 내부 테스트, 필요 시 외부 테스트
12. 최종 실기기 회귀 테스트 후 App Review 제출
