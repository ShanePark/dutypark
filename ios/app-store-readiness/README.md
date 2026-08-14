# Dutypark iOS App Store 출시 준비

> 현재 판정: 핵심 기능 구현은 후반부지만, 활성 상세 문서의 출시 차단 항목과 실기기·운영·심사 검증이 끝나지 않아 아직 출시 승인 상태가 아니다.

이 문서는 출시 준비 문서의 인덱스다. 상태, 체크 항목, 근거와 실행 절차는 각 상세 문서에서 관리한다.

## 상태 정의

- `[ ] 미착수`: 범위 또는 실행을 시작하지 않음
- `[-] 진행 중`: 구현·설정·검증이 진행 중
- `[x] 완료`: 상세 완료 조건과 검증 근거를 충족함
- `[!] 차단`: 외부 권한, 설정 또는 결정이 필요함
- `[~] 해당 없음`: 제외 근거를 상세 문서에 기록함

## P0 — 출시 차단

- `[!]` [01-apple-sign-in/README.md](./01-apple-sign-in/README.md)
- `[-]` [02-account-deletion/README.md](./02-account-deletion/README.md)
- `[!]` [03-privacy-and-ai-consent/README.md](./03-privacy-and-ai-consent/README.md)
- `[-]` [04-auth-and-session-hardening/README.md](./04-auth-and-session-hardening/README.md)

## P1 — 제출 전 필수

- `[!]` [05-push-notifications/README.md](./05-push-notifications/README.md)
- `[!]` [06-associated-domains/README.md](./06-associated-domains/README.md)
- `[!]` [07-app-store-connect/README.md](./07-app-store-connect/README.md)
- `[ ]` [08-testflight-and-review/README.md](./08-testflight-and-review/README.md)
- `[-]` [09-quality-accessibility/README.md](./09-quality-accessibility/README.md)
- `[ ]` [10-user-generated-content/README.md](./10-user-generated-content/README.md)
- `[-]` [11-release-engineering/README.md](./11-release-engineering/README.md)
- `[-]` [12-web-app-parity/README.md](./12-web-app-parity/README.md)

## 권장 순서

1. P0의 인증·계정·개인정보 차단 항목을 닫는다.
2. 웹·앱 동등성, UGC, 품질·접근성 검증을 완료한다.
3. OAuth, APNs, AASA와 운영 환경을 연결한다.
4. 동일 Release 빌드를 Archive하고 TestFlight 실기기 E2E를 통과한다.
5. App Store Connect 정보와 Review Notes를 확정한 뒤 제출한다.
6. 배포·모니터링·지원·롤백 담당자와 기준을 확인한다.

## 출시 승인 기준

- P0는 모두 완료돼야 한다.
- P1 미완료는 출시 책임자의 명시적 승인과 대응 계획이 있어야 한다.
- 제출할 동일 Release 빌드가 자동 검증과 지원 실기기 핵심 E2E를 통과해야 한다.
- 운영 OAuth, Production APNs, Universal Link와 개인정보 URL이 외부 환경에서 검증돼야 한다.
- App Store Connect 답변, Review Notes와 앱의 실제 동작이 일치해야 한다.

비밀값, 개인 키, 토큰, 비밀번호와 심사 계정 비밀번호는 문서나 Git에 기록하지 않는다.
