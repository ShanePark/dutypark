# 03. 개인정보, App Privacy와 AI 선택 동의

> 구현 상태: 개인정보 정책·AI 선택 동의·철회·Privacy Manifest 완료
> iOS 출시 검증 상태: 개인정보 보존 정책, Release Privacy Report와 App Store Connect Publish 대기
> 우선순위: P0
> 최종 확인일: 2026-08-14

[출시 준비 목록으로 돌아가기](../README.md)

## 남은 체크리스트

### P0: 개인정보와 App Store 제출

- [ ] 계정 삭제, 운영 감사 로그와 법정 보존 데이터의 근거·기간·삭제 또는 익명화 방식을 확정한다.
- [ ] App Store distribution 서명 Release Archive의 Xcode Organizer Privacy Report를 내보낸다.
- [ ] Release Privacy Report, `PrivacyInfo.xcprivacy`, 실제 포함 SDK와 아래 데이터 inventory를 대조한다.
- [ ] App Store Connect App Privacy에서 데이터 유형, 목적, 사용자 연결 여부와 tracking 답변을 최종 Release 기준으로 확정해 Publish한다.
- [ ] 로그인 없이 열리는 운영 개인정보 처리방침 URL을 App Store Connect에 입력한다.
- [ ] SDK, required-reason API, analytics, 광고 또는 crash reporting이 추가되면 inventory와 manifest 감사를 다시 연다.

### 조건부: production AI 서버 운영

이 섹션은 iOS 클라이언트 구현이나 App Store 제출 조건이 아니다. 서버가 production에서 외부 AI 처리를 활성화할 때만 적용하며, AI 기능이 비활성화된 상태의 iOS 출시를 차단하지 않는다. 클라이언트와 AI 선택 동의는 공급자 중립적으로 유지하고, 실제 처리업체와 처리 조건은 current `PRIVACY` 정책에서 공개한다.

- [ ] 실제 사용할 외부 AI 처리업체, 처리 국가, 하위처리자, 보관·삭제 조건과 해외 이전 고지 문구를 운영 계약과 법률 검토로 확정한다.
- [ ] 선택한 서비스의 입력 데이터 학습·제품 개선 사용 여부와 적용되는 데이터 처리 계약을 확인하고, 허용할 운영 조건과 담당자·확인일을 기록한다.
- [ ] Google Gemini를 선택하면 production 호출이 Cloud Billing이 활성화된 paid service로 처리되는 Cloud Project인지와 실제 계약 주체에 Google Cloud Data Processing Addendum(DPA)이 적용되는지 확인한다.
- [ ] 검토가 끝난 프로젝트와 서비스의 credential만 production 서버에 주입하고, 완료 전에는 production AI 일정 자동 분석을 비활성화한다.
- [ ] 비민감 테스트 일정으로 미동의 0건, 동의 후 1건, 철회 후 0건의 외부 전송을 네트워크·서버 로그에서 확인한다.
- [ ] iOS에서 동의하고 웹에서 철회하는 흐름과 그 반대 방향을 운영 유사 환경에서 확인한다.

## 완료 조건

- 계정 삭제, 감사 로그와 법정 보존 데이터의 처리 근거·기간·삭제 또는 익명화 방식이 current `PRIVACY` 정책과 일치한다.
- 최종 서명 Archive의 Privacy Report, Privacy Manifest와 App Store Connect App Privacy 답변이 서로 일치한다.
- 로그인 없이 열리는 개인정보 처리방침 URL이 App Store Connect에 등록되어 있다.
- production AI를 활성화하는 경우에만 선택한 외부 처리업체의 계약·처리 조건을 확인하고, 웹과 iOS에서 같은 계정의 동의·철회 상태가 외부 호출 전에 일관되게 적용된다.

## 변하지 않는 정책과 계약

### 정책 버전

| 정책 | 현행 버전 | migration |
| --- | --- | --- |
| 개인정보 처리방침 | `PRIVACY 2026-08-14` | `V2.2.32` |
| 이용약관 | `TERMS 2026-08-14` | `V2.2.36` |
| AI 선택 동의 | `AI_SCHEDULE_PARSING 2026-08-14` | `V2.2.36` |

- 신규 SSO 가입은 서버의 current `TERMS`와 `PRIVACY` 버전에 동의해야 한다.
- `V2.2.32`는 기존 동의 이력을 수정하거나 기존 회원의 재동의 gate를 만들지 않는다.
- AI 동의는 필수 가입 동의와 분리된 선택 동의다.
- 사용자가 AI 일정 자동 분석 기능을 켤 때 current `AI_SCHEDULE_PARSING` 안내를 확인하고 `GRANTED` 이벤트를 기록한다.
- 한 번 부여한 동의는 이후 정책 문구나 버전이 바뀌어도 재동의를 요구하거나 기능을 자동으로 비활성화하지 않는다.
- 사용자가 명시적으로 철회해 `REVOKED` 이벤트를 기록할 때만 AI 일정 자동 분석 기능을 끈다.
- 동의 주체는 요청을 수행한 관리자나 impersonator가 아니라 일정 owner member다.
- 버전과 관계없이 AI 선택 동의의 최신 이벤트가 `GRANTED`일 때만 유효하다.
- 일정 저장, 서버 재기동 queue 복원과 worker 외부 호출 직전에 동의를 다시 검사한다.
- 미동의 또는 철회 상태에서는 외부 AI 처리업체로 전송하지 않고 사용자가 날짜와 시간을 직접 입력할 수 있다.
- iOS와 웹은 서버의 내부 AI 공급자를 알거나 특정 공급자에 결합하지 않는다.
- 실제 외부 AI 처리업체와 처리 국가·보관·삭제·국외 이전 조건은 current `PRIVACY` 정책에서 공개한다.
- 동의 이벤트에는 member, 버전, 시각, IP와 User-Agent를 기록하며 일정 원문, 외부 AI 응답과 provider credential은 저장하지 않는다.

### App Privacy inventory

현재 후보는 모두 `App Functionality`, `Linked to User = Yes`, `Used for Tracking = No`다.

| 데이터 유형 | 실제 데이터 |
| --- | --- |
| Name | 사용자가 Dutypark 가입 화면에 직접 입력한 이름 |
| Email Address | 직접 가입 이메일과 선택적으로 기억한 이메일 |
| Photos or Videos | 프로필 사진과 이미지·영상 첨부 |
| Other User Content | 일정, D-day, 근무, Todo, 팀·친구 관계, 설명과 일반 파일 첨부 |
| User ID | Dutypark 회원 ID와 Kakao·Naver·Apple 공급자 식별자 |
| Device ID | APNs device token |
| Other Data Types | IP, User-Agent, 동의 이력, 로그인 시도, refresh session과 Web Push 구독 |

- Kakao·Naver 프로필 이름·이메일은 수집하지 않고 access token은 식별자 조회에만 일시 사용한다.
- Apple 이름·이메일 scope를 요청하지 않는다. Apple `sub`와 revoke용 암호화 refresh credential의 수명주기는 최신 개인정보 처리방침에 공개한다.
- `NSPrivacyTracking=false`, tracking domain 없음으로 유지한다.
- Required Reason API는 앱 자체 preference를 위한 UserDefaults 한 항목이며 approved reason은 `CA92.1`이다.
- 현재 별도 광고, analytics, crash reporting SDK와 앱에 내장된 third-party framework는 없다. 이 조건이 바뀌면 선언을 재검토한다.

## 구현 위치

- 개인정보 처리방침 migration: [`V2.2.32__publish_apple_sign_in_privacy_policy.sql`](../../../src/main/resources/db/migration/v2/V2.2.32__publish_apple_sign_in_privacy_policy.sql)
- 공급자 중립 약관·AI 동의 migration: [`V2.2.36__publish_provider_neutral_terms_and_ai_policy.sql`](../../../src/main/resources/db/migration/v2/V2.2.36__publish_provider_neutral_terms_and_ai_policy.sql)
- 동의 서비스: [`AiScheduleParsingConsentService.kt`](../../../src/main/kotlin/com/tistory/shanepark/dutypark/consent/service/AiScheduleParsingConsentService.kt)
- iOS 정책 모델: [`PolicyModels.swift`](../../Dutypark/Domain/Models/PolicyModels.swift)
- Privacy Manifest: [`PrivacyInfo.xcprivacy`](../../Dutypark/PrivacyInfo.xcprivacy)

## 참고

- [Apple: Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [Apple: Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Apple: Required Reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)

### 조건부 서버 운영 참고

- [Google Gemini API Additional Terms](https://ai.google.dev/gemini-api/terms)
- [Google Cloud Data Processing Addendum](https://cloud.google.com/terms/data-processing-addendum)
