# Dutypark iOS App Store 출시 준비

> 현재 판정: 핵심 기능 구현은 후반부지만, 활성 상세 문서의 출시 차단 항목과 실기기·운영·심사 검증이 끝나지 않아 아직 출시 승인 상태가 아니다.

이 문서는 출시 준비 문서의 인덱스다. 상태, 체크 항목, 근거와 실행 절차는 각 상세 문서에서 관리한다.

## 단계별 진행과 문서 현행화 규칙

- 출시 준비는 한 번에 한 단계씩 진행하고, 현재 단계의 완료 여부와 근거를 확인하기 전에는 다음 단계를 시작하지 않는다.
- 구현·설정·검증·배포 작업이 끝나면 같은 작업 안에서 이 인덱스와 관련 상세 문서 및 하위 문서의 상태, 체크리스트, 최종 확인일과 검증 근거를 즉시 현행화한다.
- App Store Connect, Apple Developer, 운영 서버와 실기기처럼 저장소 밖에서 수행한 작업은 실제 결과를 확인한 뒤에만 완료 처리한다. 확인할 수 없는 항목은 사용자 확인 또는 증거를 기다리는 상태로 남긴다.

## 상태 정의

- `[ ] 미착수`: 범위 또는 실행을 시작하지 않음
- `[-] 진행 중`: 구현·설정·검증이 진행 중
- `[x] 완료`: 상세 완료 조건과 검증 근거를 충족함
- `[!] 차단`: 외부 권한, 설정 또는 결정이 필요함
- `[~] 해당 없음`: 제외 근거를 상세 문서에 기록함

한 항목 안에서 구현과 출시 준비 상태가 다르면 `구현 [x] / 출시 검증 [!]`처럼 분리해 적는다. 따라서 `[!]`는 코드 미구현을 뜻하지 않을 수 있으며, 외부 설정이나 운영·실기기 검증이 남은 경우에도 사용한다.

## P0 — 출시 차단

- `iOS·서버·웹 로그인/가입 구현 [x] / 출시 검증 [!]` [01-apple-sign-in/README.md](./01-apple-sign-in/README.md)
- `[-]` [02-account-deletion/README.md](./02-account-deletion/README.md)
- `정책·AI 동의·Manifest 구현 [x] / App Store 개인정보 검증 [!]` [03-privacy-and-ai-consent/README.md](./03-privacy-and-ai-consent/README.md)
- `[-]` [04-auth-and-session-hardening/README.md](./04-auth-and-session-hardening/README.md)

## P1 — 제출 전 필수

- `[!]` [05-push-notifications/README.md](./05-push-notifications/README.md)
- `[!]` [06-associated-domains/README.md](./06-associated-domains/README.md)
- `앱 레코드 [x] / 메타데이터·Privacy·규제 응답 [!]` [07-app-store-connect/README.md](./07-app-store-connect/README.md)
- `자동 테스트·Archive·Validate·Upload·Connect 처리·내부 그룹·빌드·테스터 초대·리딤·설치·로그인 smoke [x] / 운영 기능·실기기 E2E [ ]` [08-testflight-and-review/README.md](./08-testflight-and-review/README.md)
- `[-]` [09-quality-accessibility/README.md](./09-quality-accessibility/README.md)
- `[ ]` [10-user-generated-content/README.md](./10-user-generated-content/README.md)
- `인증서·Archive·Validate·Upload·Connect 처리 [x] / 최종 패키징 검증 [ ]` [11-release-engineering/README.md](./11-release-engineering/README.md)
- `[x]` [13-mobile-web-parity-ui/README.md](./13-mobile-web-parity-ui/README.md)

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
