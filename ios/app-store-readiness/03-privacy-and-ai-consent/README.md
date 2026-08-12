# 개인정보 처리방침, App Privacy, 제3자 AI 동의

- 작성일: 2026-08-12
- 우선순위: 제출 전 필수
- 상태: 문서·구현 불일치 및 별도 동의 미구현
- 관련 심사 항목: App Review Guidelines 5.1.1, 5.1.2

## 목표

실제 수집·저장·전송 동작과 개인정보 처리방침 및 App Store Connect의 App Privacy 답변을 일치시킨다.
일정 문구가 Google AI로 전송되기 전에 제공자와 목적을 알리고 명시적 동의를 받으며, 거부해도 수동 입력으로 핵심 기능을 사용할 수 있게 한다.

## 현재 확인된 위치

- 현재 개인정보 처리방침 마이그레이션: [V2.1.6__update_privacy_policy_remove_email.sql](../../../src/main/resources/db/migration/v2/V2.1.6__update_privacy_policy_remove_email.sql)
- 웹 인증 클라이언트: [client.ts](../../../frontend/src/api/client.ts)
- iOS 알림 등록: [APNsRegistration.swift](../../Dutypark/Features/Notifications/APNsRegistration.swift)
- iOS OAuth 처리: [MobileOAuthClient.swift](../../Dutypark/Features/Auth/MobileOAuthClient.swift)
- iOS 로그인 화면: [LoginView.swift](../../Dutypark/Features/Auth/LoginView.swift)
- iOS entitlement: [Dutypark.entitlements](../../Dutypark/Dutypark.entitlements)
- 웹 개인정보 관련 번역: [messages](../../../frontend/src/i18n/messages/)

경로가 리팩터링되면 실제 클래스와 설정을 다시 찾아 링크를 갱신한다.

## 먼저 바로잡을 문서 모순

- [ ] 처리방침의 `쿠키를 사용하지 않는다`는 설명을 실제 HttpOnly access/refresh cookie 사용과 일치시킨다.
- [ ] JWT를 `localStorage`에 저장한다는 설명을 제거하고 실제 쿠키 및 Bearer fallback 동작을 기술한다.
- [ ] 설정에서 개인정보를 직접 삭제할 수 있다는 설명은 계정 삭제 구현 완료 시점과 맞춘다.
- [ ] 아직 계정 삭제가 문의 방식이라면 구현 전까지 가능한 절차를 정확히 표시하되 출시 전 앱 내 삭제를 완성한다.
- [ ] 수집 항목, 목적, 보유 기간, 삭제 방법, 위탁·제3자 제공을 실제 데이터 흐름으로 다시 검토한다.
- [ ] 정책 시행일, 변경 공지 방식, 담당자 연락처가 유효한지 확인한다.

## 데이터 인벤토리

- [ ] 계정 식별자, 이름, 이메일, 소셜 제공자 식별자를 목록화한다.
- [ ] Apple `sub`, Private Relay 이메일, 최초 로그인 시 제공되는 이름의 저장 여부를 추가한다.
- [ ] 일정 제목·내용, Todo, 팀·친구 관계, 프로필과 첨부파일을 사용자 콘텐츠로 분류한다.
- [ ] IP 주소, 접속 로그, 쿠키, refresh session, 기기·앱 버전 수집 여부를 확인한다.
- [ ] APNs device token과 웹 푸시 subscription의 목적과 보유 기간을 추가한다.
- [ ] 진단·충돌·성능 SDK가 있다면 수집 항목과 사용자 연결 여부를 확인한다.
- [ ] 삭제, 익명화, 백업 만료까지 실제 최대 보유 기간을 데이터별로 기록한다.
- [ ] 개발·스테이징·운영 로그에 개인정보 또는 토큰이 출력되는지 점검한다.

## Apple 로그인 데이터

- [ ] Apple 로그인의 `sub`를 안정적인 계정 식별자로 사용하고 목적을 공개한다.
- [ ] 이름과 이메일은 최초 승인에서만 올 수 있으므로 꼭 필요한 범위만 저장한다.
- [ ] Private Relay 이메일을 일반 이메일과 동일하게 처리하되 성격을 문서에 설명한다.
- [ ] 계정 연결 과정에서 Apple 식별자를 Kakao/Naver 식별자와 결합하는지 공개한다.
- [ ] relay 이메일로 메일을 보낸다면 Apple의 private email relay 설정을 완료한다.
- [ ] 계정 삭제 시 Apple 토큰 revoke와 로컬 식별자 삭제를 처리한다.

## App Store Connect App Privacy

- [ ] 데이터 인벤토리를 기준으로 `Data Used to Track You` 여부를 사실대로 판단한다.
- [ ] 이름, 이메일, 사용자 ID 등 Contact Info와 Identifiers 항목을 확인한다.
- [ ] 일정, Todo, 사진·첨부파일을 User Content 항목에 반영한다.
- [ ] IP·접속·진단 데이터가 Usage Data 또는 Diagnostics에 해당하는지 확인한다.
- [ ] 각 항목의 목적을 App Functionality, Analytics 등 실제 용도로 선택한다.
- [ ] 계정이나 기기에 연결되는 데이터인지 `Linked to You`를 정확히 답한다.
- [ ] 서드파티 SDK와 서버측 Google AI 전송까지 포함해 답변한다.
- [ ] 앱 또는 서버 동작이 바뀔 때 App Privacy 답변을 함께 갱신하는 절차를 둔다.

## Privacy Manifest 점검

- [ ] 앱 타깃에 `PrivacyInfo.xcprivacy`가 있는지 확인하고 없으면 추가한다.
- [ ] Required Reason API 사용을 Xcode Privacy Report와 아카이브 경고로 점검한다.
- [ ] 포함된 SDK의 privacy manifest와 서명 요구 사항을 최신 목록과 대조한다.
- [ ] 자체 수집 데이터와 tracking domain 선언이 실제 동작과 일치하는지 확인한다.
- [ ] Release archive에서 생성되는 privacy report를 보관하고 제출 전 검토한다.
- [ ] 새 SDK를 추가할 때 manifest와 App Privacy를 검토하는 체크를 PR 템플릿에 넣는다.

## Google AI 전송 현황과 고지

일정의 제목 또는 문구를 서버가 Google AI에 보내 시간 정보를 추출한다.
사용자는 전송 전에 최소한 다음 내용을 이해할 수 있어야 한다.

- [ ] Google이 데이터 수신자라는 점
- [ ] 일정 문구에서 시간 정보를 자동 추출하는 목적
- [ ] 실제 전송 범위와 전송하지 않는 필드
- [ ] Google 및 Dutypark의 보유·삭제 정책
- [ ] 동의가 선택 사항이며 거부해도 수동 시간 입력이 가능하다는 점
- [ ] 언제든 동의를 철회할 수 있는 설정 경로

## 동의 UX

- [ ] 가입 약관 전체 동의에 숨기지 않고 AI 전송을 별도의 선택 동의로 제공한다.
- [ ] 일정 자동 시간 인식을 처음 사용할 때 동의 화면을 표시한다.
- [ ] `동의`, `동의하지 않고 수동 입력` 선택지를 동등하게 이해할 수 있게 표시한다.
- [ ] 동의 전에 어떤 문구가 어디로 왜 전송되는지 짧게 설명하고 상세 정책으로 연결한다.
- [ ] 설정에 AI 자동 인식 켜기/끄기와 상세 설명 진입점을 둔다.
- [ ] 철회 즉시 새 일정 문구가 AI 큐에 들어가지 않게 한다.
- [ ] 이미 큐에 들어간 작업의 취소 가능 범위와 처리 방식을 정한다.
- [ ] 동의하지 않은 사용자의 일정 생성·수정은 수동 시간 입력으로 정상 완료된다.

## 동의 기록과 서버 강제

- [ ] 동의 여부, 정책 버전, 동의 시각, 철회 시각을 서버에 저장한다.
- [ ] 기기 로컬 값만 믿지 않고 서버가 AI 큐 등록 전에 현재 동의를 검사한다.
- [ ] 관리자가 대신 생성하거나 impersonation한 경우 누구의 동의를 적용할지 정한다.
- [ ] 보조 계정에는 계정 소유자와 실제 사용자의 동의 주체를 명확히 한다.
- [ ] 동의 정책이 중요하게 바뀌면 새 버전에 재동의를 받는다.
- [ ] 동의 API는 반복 호출에 안전하고 변경 이력을 감사 가능하게 보존한다.
- [ ] 일정 원문, AI 요청·응답, API 키를 동의 감사 로그에 저장하지 않는다.

## 백엔드 구현 체크리스트

- [ ] AI 동의 조회·부여·철회 API와 기계 판독 가능한 오류 코드를 추가한다.
- [ ] 일정 생성·수정 모두 `ScheduleTimeParsingQueueManager` 등록 전에 동의를 검사한다.
- [ ] 미동의 상태에서는 파싱 상태가 영구 대기나 오류로 남지 않게 정의한다.
- [ ] 철회 후 예약된 작업과 재시도 작업이 외부로 전송되지 않게 한다.
- [ ] Google 요청에 목적상 필요하지 않은 사용자·팀 식별자를 포함하지 않는다.
- [ ] 보존 기간에 따라 AI 요청 관련 로그와 큐 데이터를 삭제한다.
- [ ] 개인정보 처리방침의 새 버전과 동의 버전을 배포 순서에 맞게 등록한다.

## iOS 및 웹 구현 체크리스트

- [ ] iOS 최초 사용 동의, 설정 토글, 수동 입력 fallback을 구현한다.
- [ ] 웹에도 같은 선택지와 서버 동의 상태를 제공한다.
- [ ] 플랫폼 간 동의 상태가 계정 기준으로 즉시 동기화되는지 확인한다.
- [ ] 비동의·철회 사용자가 자동 인식 실패 알림을 반복해서 받지 않게 한다.
- [ ] 모든 사용자 문구를 `ko`, `en`, `ja`, `zh`, `es`에 제공한다.
- [ ] VoiceOver, Dynamic Type, 44pt 터치 영역과 라이트·다크 모드를 확인한다.

## 테스트

- [ ] 신규 사용자는 동의 전 Google AI 요청이 0건인지 검증한다.
- [ ] 동의한 사용자의 일정 생성·수정이 큐에 등록되고 정상 파싱되는지 검증한다.
- [ ] 거부한 사용자가 수동 시간으로 일정 생성·수정을 완료하는지 검증한다.
- [ ] 철회 직후 신규 작업과 기존 재시도 작업이 전송되지 않는지 검증한다.
- [ ] 정책 버전 변경 시 필요한 사용자에게만 재동의가 표시되는지 검증한다.
- [ ] iOS에서 동의하고 웹에서 철회하는 교차 플랫폼 시나리오를 검증한다.
- [ ] 보조 계정, 관리자 작업, impersonation의 동의 규칙을 검증한다.
- [ ] Privacy Report와 네트워크 관찰로 문서에 없는 수집·전송이 없는지 확인한다.
- [ ] App Store Connect 답변을 실제 Release 빌드와 최종 대조한다.

## 완료 조건

- [ ] 개인정보 처리방침의 쿠키, 저장 위치, 직접 삭제 설명이 실제 구현과 일치한다.
- [ ] APNs token, Apple 식별자·relay 이메일, 사용자 콘텐츠가 데이터 인벤토리에 포함된다.
- [ ] App Privacy와 privacy manifest가 Release archive의 실제 동작을 반영한다.
- [ ] Google AI 전송 전에 제공자·목적·전송 범위를 알린 명시적 선택 동의를 받는다.
- [ ] 거부와 철회가 가능하며 수동 시간 입력 기능은 제한 없이 동작한다.
- [ ] 서버 자동 테스트, iOS·웹 회귀 테스트, 실기기 네트워크 확인이 통과한다.

## 공식 자료

- [Apple App Review Guidelines 5.1](https://developer.apple.com/app-store/review/guidelines/#privacy)
- [Apple: Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [Apple: Describing data use in privacy manifests](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests)
- [Apple: Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)
