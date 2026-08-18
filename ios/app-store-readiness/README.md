# Dutypark iOS App Store 출시 준비

제출까지 **실제로 만들어야 하거나 설정해야 하는 것**만 적는다. "동작하는지 확인한다" 류의 검증 항목은 여기서 관리하지 않고, 문제가 드러나면 그때 이슈로 다룬다.

## 1. 사용자 신고·차단 (구현 완료, 배포 대기)

App Review Guideline 1.2가 요구하는 항목이다. Dutypark는 회원 검색으로 모르는 사람에게 친구 요청을 보낼 수 있고, 공개 달력은 비로그인 상태에서도 열린다. 확정된 설계와 작업 분할은 [docs/design/ugc-report-block-plan.md](../../docs/design/ugc-report-block-plan.md)를 따른다. 아래는 서버·웹·iOS에 모두 구현되었고, 운영 배포는 남아 있다.

- [x] 사용자 차단·차단 목록·차단 해제를 서버, 웹, iOS에 구현한다. 차단하면 일정·Todo·프로필·첨부, 검색, 친구 요청과 알림이 양방향으로 끊긴다.
- [x] 일정, Todo, 프로필 사진, 첨부파일, 공개 달력에서 신고 동작을 제공하고 사유·대상·신고자·시각을 서버에 저장한다.
- [x] 운영자가 신고 목록과 대상 콘텐츠를 조회하고 숨김·삭제·계정 제한을 실행할 관리자 화면을 만든다. (`/admin/reports`, `/admin/inquiries`, 회원 상세의 계정 정지·해제)
- [x] 금지 콘텐츠, 제재 단계, 이의제기와 신고 후 24시간 이내 조치 기준을 담은 이용 정책을 로그인 없이 열리는 URL로 공개한다. (이용약관 `2026-08-18` 버전 제8~11조, https://dutypark.o-r.kr/terms)
- [x] 실제 응답 가능한 문의 이메일 또는 양식을 앱 설정과 Support URL에 게시한다. (https://dutypark.o-r.kr/support, iOS 더보기 → 문의하기, 게스트 화면에서도 접근 가능)

## 2. 운영 환경 설정

- [ ] APNs Auth Key(`.p8`)를 `Sandbox & Production` / `Team Scoped`로 발급하고 `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_PRIVATE_KEY`를 운영 서버에 주입한다. 셋 중 하나라도 비면 APNs 발송이 비활성화된다.
- [ ] `https://dutypark.o-r.kr/.well-known/apple-app-site-association`를 운영에 배포한다. 배포 전에는 Universal Link가 동작하지 않는다.
- [ ] Apple 로그인 운영 환경변수(`APPLE_CLIENT_ID`, `APPLE_WEB_CLIENT_ID`, `APPLE_WEB_REDIRECT_URI`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_CREDENTIAL_ENCRYPTION_KEY`)를 주입한다. private key와 암호화 key는 secret manager에서만 공급한다.
- [ ] 운영 프런트엔드 빌드에 `VITE_APPLE_CLIENT_ID=io.github.shanepark.dutypark.web`, `VITE_APPLE_REDIRECT_URI=https://dutypark.o-r.kr/auth/apple/callback`을 반영한다.

## 3. App Store Connect 입력물

- [ ] 앱 이름, 기본 언어, SKU, 기본·보조 카테고리를 확정한다.
- [ ] 판매 국가·지역을 정한다. EU에 배포하면 DSA trader 정보와 연락처·주소 검증을 완료한다.
- [ ] App Store가 요구하는 기기 크기별 스크린샷을 전용 테스트 데이터로 제작한다.
- [ ] `ko`, `en`의 앱 이름, 부제, 설명, 키워드, 프로모션 텍스트와 `What's New`를 작성한다.
- [ ] 로그인 없이 열리는 지원 URL과 개인정보 처리방침 URL을 입력한다. 지원 URL은 `https://dutypark.o-r.kr/support`, 개인정보 처리방침 URL은 `https://dutypark.o-r.kr/privacy`.
- [ ] App Privacy에 데이터 유형, 목적, 사용자 연결 여부와 non-tracking 답변을 입력해 Publish한다.
- [ ] 연령 등급, 콘텐츠 권리, 광고 식별자와 수출 규정 질문에 답한다.
- [ ] 신고·차단 기능을 사실대로 선언한다. 답: **있음** — 신고는 멤버 달력 `⋯` 메뉴·일정 행·Todo 상세에서, 차단은 친구 카드 `⋯`와 멤버 달력 `⋯`에서 가능하고, 접수된 신고는 24시간 이내에 운영자가 처리한다.
- [ ] App Review 연락처를 입력하고 심사용 전용 계정과 팀·친구 기능용 보조 계정을 준비한다.
- [ ] Review Notes에 로그인, 소셜·Apple 로그인, 회원 탈퇴, 푸시, Universal Link, 신고·차단의 재현 경로를 작성한다.
- [ ] AI 선택 동의와 외부 AI 전송·철회·수동 입력 경로를 current 개인정보 처리방침과 일치하게 설명한다.

## 4. 개인정보 처리방침 확정

- [ ] 계정 삭제, 운영 감사 로그와 법정 보존 데이터의 근거·기간·삭제 또는 익명화 방식을 정책 문구에 반영한다.
- [ ] production AI 일정 분석을 켤 경우에만: 외부 AI 처리업체, 처리 국가, 보관·삭제와 국외 이전 조건을 정책에 공개한다. 그 전까지 production AI 분석은 비활성 상태로 둔다.

## 5. 제출

- [ ] 위 변경을 반영한 Release Archive를 새 빌드 번호로 생성해 App Store Connect에 업로드한다.
- [ ] 업로드한 빌드를 선택하고 출시 방식을 정해 App Review에 제출한다.

## 참고

- Team ID `2V47G42CDS` / Bundle ID `io.github.shanepark.dutypark` / 웹 Services ID `io.github.shanepark.dutypark.web`
- 마지막 업로드: `Dutypark` 1.0 (1) — Validate·업로드·내부 TestFlight 설치까지 완료
- [App Review Guidelines 1.2 — UGC](https://developer.apple.com/app-store/review/guidelines/#user-generated-content)
- [App Store Connect: DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)

비밀값, 개인 키, 토큰과 심사 계정 비밀번호는 문서나 Git에 기록하지 않는다.
