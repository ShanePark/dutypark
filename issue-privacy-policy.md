# Privacy Policy & Terms Implementation Plan

## Background

- Terms of Service exists but references non-existent "Privacy Policy"
- No consent records stored in DB
- Sensitive data (passwords) can leak to Slack on errors
- No account deletion feature

---

## Phase 1: Slack Security Fix

**Goal:** Prevent sensitive data exposure in error notifications

- [x] Skip request body logging for `/api/auth/*` endpoints in `ErrorDetectAdvisor.kt`

---

## Phase 2: Policy Content

**Goal:** Write legally compliant policy documents

- [ ] Review and finalize privacy policy content below
- [ ] Review and finalize terms of service content below
- [ ] Replace placeholder `[DPO_EMAIL]` with actual contact email

---

### 2.1 개인정보 처리방침 (Privacy Policy) v1.0.0

```
개인정보 처리방침

시행일: [YYYY-MM-DD]

Dutypark(이하 "서비스")는 이용자의 개인정보를 중요시하며, 「개인정보 보호법」을 준수합니다.
본 개인정보 처리방침은 서비스가 수집하는 개인정보의 항목, 수집 목적, 보유 기간, 제3자 제공 등에 대해 안내합니다.

제1조 (개인정보의 수집 항목 및 수집 방법)

1. 수집하는 개인정보 항목

| 구분 | 수집 항목 | 필수/선택 |
|------|----------|-----------|
| 소셜 로그인(카카오) | 이름, 카카오 계정 고유 식별자 | 필수 |
| 서비스 이용 | 일정, 기념일(D-Day), 근무표, 할일(Todo), 첨부파일 | 선택 |
| 관계 정보 | 친구 목록, 가족 관계, 관리자 관계 | 선택 |
| 프로필 | 프로필 사진 | 선택 |
| 자동 수집 | IP 주소, 기기 정보(OS, 브라우저, 기기명), 접속 일시 | 필수 |

2. 수집 방법
- 카카오 소셜 로그인 시 이용자가 이름 직접 입력
- 카카오 OAuth 연동 시 카카오 계정 식별자 자동 수집
- 서비스 이용 과정에서 자동 생성 및 수집 (IP, 기기 정보 등)


제2조 (개인정보의 수집 및 이용 목적)

서비스는 다음의 목적을 위해 개인정보를 수집 및 이용합니다.

| 목적 | 상세 내용 |
|------|----------|
| 회원 관리 | 회원 식별, 가입 의사 확인, 본인 확인, 부정 이용 방지 |
| 서비스 제공 | 일정 관리, 근무표 관리, 친구/가족 공유 기능 제공 |
| 보안 및 안전 | 비정상적 접근 탐지, 세션 관리, 오류 모니터링 |
| 서비스 개선 | 일정 내용에서 시간 정보 자동 추출(AI 활용) |


제3조 (개인정보의 보유 및 이용 기간)

서비스는 개인정보 수집 및 이용 목적이 달성된 후에는 해당 정보를 지체 없이 파기합니다.

| 항목 | 보유 기간 | 비고 |
|------|----------|------|
| 회원 계정 정보 | 회원 탈퇴 시까지 | 탈퇴 처리 완료 시 파기 |
| 일정, 기념일, 근무표, 할일 | 회원 탈퇴 시까지 | 이용자가 개별 삭제 가능 |
| 첨부파일 | 회원 탈퇴 시까지 | 이용자가 개별 삭제 가능 |
| 로그인 세션 정보 | 7일 | 자동 삭제 |
| 임시 업로드 파일 | 24시간 | 자동 삭제 |
| 서비스 로그 | 90일 | 자동 삭제 |


제4조 (개인정보의 제3자 제공)

서비스는 이용자의 개인정보를 제2조에서 명시한 범위 내에서만 이용하며,
원칙적으로 이용자의 사전 동의 없이 제3자에게 제공하지 않습니다.
다만, 다음의 경우에는 예외로 합니다.

1. 서비스 제공을 위한 제3자 제공

| 제공받는 자 | 제공 항목 | 제공 목적 | 보유 기간 |
|------------|----------|----------|----------|
| 카카오 | 인증 코드 | 소셜 로그인 처리 | 인증 완료 시 즉시 파기 |
| Google (Gemini AI) | 일정 내용 텍스트 | 시간 정보 자동 추출 | 처리 완료 시 즉시 파기 |
| Slack | 오류 로그(민감정보 제외) | 서비스 오류 모니터링 | Slack 정책에 따름 |

2. 법령에 따른 제공
- 법령의 규정에 의거하거나, 수사 목적으로 법령에 정해진 절차와 방법에 따라 수사기관의 요구가 있는 경우


제5조 (개인정보의 파기 절차 및 방법)

1. 파기 절차
- 이용자가 회원 탈퇴를 요청하거나 개인정보 수집 및 이용 목적이 달성된 경우 지체 없이 파기합니다.

2. 파기 방법
- 전자적 파일: 복구 불가능한 방법으로 영구 삭제
- 종이 문서: 분쇄기로 분쇄하거나 소각


제6조 (이용자의 권리와 행사 방법)

이용자는 다음의 권리를 행사할 수 있습니다.

1. 개인정보 열람 요청
2. 개인정보 정정 요청
3. 개인정보 삭제 요청
4. 개인정보 처리 정지 요청

권리 행사 방법:
- 서비스 내 설정 메뉴를 통해 직접 처리
- 개인정보 보호책임자에게 이메일로 요청

요청 처리 기한: 요청일로부터 10일 이내


제7조 (개인정보의 안전성 확보 조치)

서비스는 개인정보의 안전성 확보를 위해 다음과 같은 조치를 취하고 있습니다.

1. 관리적 조치: 개인정보 취급 직원 최소화, 정기적 보안 교육
2. 기술적 조치:
   - 비밀번호 암호화 저장 (bcrypt 해시)
   - HTTPS 암호화 통신
   - 접근 권한 관리 및 접근 통제
3. 물리적 조치: 서버 접근 통제


제8조 (쿠키 및 로컬 스토리지)

서비스는 쿠키(Cookie)를 사용하지 않으며, 다음의 정보를 브라우저 로컬 스토리지에 저장합니다.

| 항목 | 목적 | 삭제 방법 |
|------|------|----------|
| 인증 토큰 (JWT) | 로그인 상태 유지 | 로그아웃 시 자동 삭제, 브라우저 설정에서 수동 삭제 가능 |

이용자는 브라우저 설정을 통해 로컬 스토리지 데이터를 삭제할 수 있습니다.


제9조 (개인정보 보호책임자)

서비스는 개인정보 처리에 관한 업무를 총괄해서 책임지고,
이용자의 개인정보 관련 문의사항 및 불만 처리를 위해 아래와 같이 개인정보 보호책임자를 지정하고 있습니다.

개인정보 보호책임자
- 이메일: [DPO_EMAIL]

이용자는 서비스 이용 중 발생한 모든 개인정보 보호 관련 문의, 불만, 피해 구제 등에 관한 사항을
개인정보 보호책임자에게 문의할 수 있습니다.


제10조 (개인정보 처리방침의 변경)

본 개인정보 처리방침은 법령, 정책 또는 서비스 변경에 따라 변경될 수 있습니다.
변경 시에는 시행일 최소 7일 전에 서비스 내 공지사항을 통해 안내합니다.
다만, 이용자 권리에 중요한 변경이 있는 경우 최소 30일 전에 안내합니다.

- 공고일: [YYYY-MM-DD]
- 시행일: [YYYY-MM-DD]
```

---

### 2.2 이용약관 (Terms of Service) v1.0.0

```
이용약관

시행일: [YYYY-MM-DD]

제1조 (목적)

본 약관은 Dutypark(이하 "서비스")의 이용 조건 및 절차, 이용자와 서비스 제공자 간의 권리,
의무, 책임사항 및 기타 필요한 사항을 규정함을 목적으로 합니다.


제2조 (정의)

1. "이용자"란 본 약관에 따라 서비스에 접속하여 서비스를 이용하는 회원 및 비회원을 말합니다.
2. "회원"이란 서비스에 개인정보를 제공하여 회원 등록을 한 자로서,
   서비스가 제공하는 서비스를 계속적으로 이용할 수 있는 자를 말합니다.
3. "비회원"이란 회원에 가입하지 않고 서비스가 제공하는 서비스를 이용하는 자를 말합니다.


제3조 (약관의 효력 및 변경)

1. 본 약관은 서비스 화면에 게시하거나 기타의 방법으로 이용자에게 공지함으로써 효력이 발생합니다.
2. 서비스 제공자는 필요한 경우 관련 법령을 위반하지 않는 범위 내에서 본 약관을 변경할 수 있습니다.
3. 약관 변경 시 시행일 최소 7일 전에 공지하며, 이용자에게 불리한 변경의 경우 30일 전에 공지합니다.
4. 변경된 약관에 동의하지 않는 이용자는 서비스 이용을 중단하고 탈퇴할 수 있습니다.


제4조 (회원 가입)

1. 이용자는 서비스가 정한 가입 양식에 따라 회원정보를 기입한 후
   본 약관 및 개인정보 처리방침에 동의함으로써 회원 가입을 신청합니다.
2. 서비스는 다음 각 호에 해당하지 않는 한 회원으로 등록합니다.
   - 가입 신청자가 본 약관에 의거하여 이전에 회원 자격을 상실한 적이 있는 경우
   - 등록 내용에 허위, 기재누락, 오기가 있는 경우
   - 기타 회원으로 등록하는 것이 서비스의 기술상 현저히 지장이 있다고 판단되는 경우


제5조 (회원 탈퇴 및 자격 상실)

1. 회원은 개인정보 보호책임자에게 이메일로 탈퇴를 요청할 수 있으며, 서비스는 요청일로부터 10일 이내에 탈퇴를 처리합니다.
2. 탈퇴 시 회원의 모든 데이터(일정, 기념일, 근무표, 첨부파일 등)는 삭제되며 복구할 수 없습니다.
3. 회원이 다음 각 호에 해당하는 경우 서비스는 회원 자격을 제한 또는 상실시킬 수 있습니다.
   - 가입 신청 시 허위 내용을 등록한 경우
   - 서비스를 이용하여 법령 또는 본 약관이 금지하는 행위를 하는 경우
   - 다른 이용자의 서비스 이용을 방해하거나 정보를 도용하는 경우


제6조 (서비스 이용)

1. 서비스 이용은 회원 가입 승낙 직후부터 가능합니다.
2. 서비스 이용시간은 연중무휴 24시간을 원칙으로 합니다.
   단, 서비스 제공자의 업무상 또는 기술상의 이유로 서비스가 일시 중단될 수 있습니다.


제7조 (서비스의 변경 및 중지)

1. 서비스 제공자는 필요한 경우 서비스의 내용을 변경하거나 제공을 중지할 수 있습니다.
2. 서비스 변경 또는 중지 시 사전에 공지합니다. 단, 불가피한 경우 사후에 공지할 수 있습니다.
3. 다음과 같은 경우 서비스 제공을 일시적으로 중단할 수 있습니다.
   - 서비스용 설비의 보수 등 공사로 인한 경우
   - 전기통신사업법에 규정된 기술적 장애의 발생
   - 기타 불가항력적 사유가 있는 경우


제8조 (개인정보보호)

서비스 제공자는 이용자의 개인정보를 보호하기 위해 노력하며,
개인정보의 수집, 이용, 제공, 보호에 관한 사항은 별도의 "개인정보 처리방침"에 따릅니다.


제9조 (이용자의 의무)

이용자는 서비스 이용에 있어서 다음의 행위를 하여서는 안 됩니다.
1. 신청 또는 변경 시 허위 내용의 등록
2. 타인의 정보 도용
3. 서비스에 게시된 정보의 무단 변경
4. 서비스가 정한 정보 이외의 정보(컴퓨터 프로그램 등)의 송신 또는 게시
5. 서비스 및 제3자의 저작권 등 지적재산권에 대한 침해
6. 서비스 및 제3자의 명예를 손상시키거나 업무를 방해하는 행위
7. 외설 또는 폭력적인 메시지, 화상, 음성, 기타 공서양속에 반하는 정보를 서비스에 공개 또는 게시하는 행위


제10조 (저작권의 귀속 및 이용 제한)

1. 서비스가 제공하는 콘텐츠(텍스트, 그래픽, 로고, 아이콘, 이미지 등)의 저작권은 서비스 제공자에게 귀속됩니다.
2. 이용자가 서비스 내에 게시한 콘텐츠의 저작권은 해당 이용자에게 귀속됩니다.
3. 이용자는 서비스를 이용함으로써 얻은 정보를 서비스 제공자의 사전 승낙 없이
   복제, 배포, 방송 기타 방법에 의하여 상업적으로 이용할 수 없습니다.


제11조 (면책 조항)

1. 서비스 제공자는 천재지변, 전쟁, 테러 행위, 기타 불가항력적 사유로 인해
   서비스를 제공할 수 없을 경우에는 서비스 제공에 대한 책임이 면제됩니다.
2. 서비스 제공자는 이용자의 귀책사유로 인한 서비스 이용의 장애에 대하여 책임을 지지 않습니다.
3. 서비스 제공자는 이용자가 서비스의 이용과 관련하여 기대하는 이익이나
   서비스에 게시된 정보의 이용으로 발생하는 손해 등에 대하여 책임을 지지 않습니다.
4. 서비스 제공자는 이용자 간 또는 이용자와 제3자 간에 서비스를 매개로 하여
   발생한 분쟁에 대해 개입할 의무가 없으며, 이로 인한 손해를 배상할 책임이 없습니다.


제12조 (분쟁 해결)

1. 서비스 제공자와 이용자는 서비스 이용과 관련하여 발생한 분쟁을 원만하게 해결하기 위하여 노력합니다.
2. 분쟁이 해결되지 않을 경우, 대한민국 법률에 따르며 관할 법원은 민사소송법상의 관할 법원으로 합니다.


부칙

- 공고일: [YYYY-MM-DD]
- 시행일: [YYYY-MM-DD]
```

---

## Phase 3: Policy Storage

**Goal:** Store policy versions in DB for versioning and audit

### 3.1 Database Schema

```sql
CREATE TABLE policy_version (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    policy_type VARCHAR(50) NOT NULL,      -- TERMS, PRIVACY
    version VARCHAR(20) NOT NULL,          -- 1.0.0
    effective_date DATE NOT NULL,
    content MEDIUMTEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY (policy_type, version)
);
```

### 3.2 Backend

- [x] `PolicyVersion` entity
- [x] `PolicyVersionRepository`
- [x] `PolicyService` - `getCurrentVersion(type)`, `getByVersion(type, version)`
- [x] API endpoints:
  - `GET /api/policies/current` - current versions
  - `GET /api/policies/{type}/{version}` - specific content

### 3.3 Frontend

- [x] `/terms` page - display terms content
- [x] `/privacy` page - display privacy policy content
- [x] Login page links to both pages

---

## Phase 4: Consent Management

**Goal:** Record and track user consent with proof

### 4.1 Database Schema

```sql
CREATE TABLE member_consent (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    member_id BIGINT NOT NULL,
    consent_type VARCHAR(50) NOT NULL,     -- TERMS, PRIVACY, MARKETING
    consent_version VARCHAR(20) NOT NULL,
    consented_at DATETIME NOT NULL,
    ip_address VARCHAR(45),
    user_agent VARCHAR(500),
    FOREIGN KEY (member_id) REFERENCES member(id) ON DELETE CASCADE,
    INDEX (member_id, consent_type)
);
```

### 4.2 Backend

- [x] `MemberConsent` entity with `ConsentType` enum
- [x] `MemberConsentRepository`
- [x] `ConsentService` - `recordConsent()` only (minimal)
- [x] Update `OAuthController.ssoSignup()` to record consent after member creation

### 4.3 Frontend

- [x] Update `SsoSignupView.vue`:
  - 2 checkboxes (Terms, Privacy) + fetch content from `/api/policies/current`
- [x] Each checkbox links to full policy page (`/terms`, `/privacy`)
- [x] Update `SsoSignupRequest` DTO to include `privacyAgree: Boolean`

### 4.4 Existing Users Migration

- [ ] Migration SQL: Create consent records for existing members
  ```sql
  -- Note: Member table has no created_date, use migration timestamp
  INSERT INTO member_consent (member_id, consent_type, consent_version, consented_at)
  SELECT id, 'TERMS', '1.0.0', NOW() FROM member;

  INSERT INTO member_consent (member_id, consent_type, consent_version, consented_at)
  SELECT id, 'PRIVACY', '1.0.0', NOW() FROM member;
  ```
- Note: `ip_address`, `user_agent` will be NULL for migrated records
- Note: `consented_at` will be migration date (not original signup date) since Member table lacks `created_date`

### 4.5 Policy Update Re-consent

- [ ] Check consent version on login/API access
- [ ] If user's consent version < current policy version:
  - Show consent modal before allowing service use
  - Record new consent after user agrees

---

## Summary

| Phase | Task | Priority |
|-------|------|----------|
| 1 | Slack auth URL exclusion | P0 |
| 2 | Write privacy policy & update terms | P0 |
| 3 | Policy version DB & pages | P1 |
| 4 | Consent records & signup flow | P1 |

---

## Notes

- Version format: Semantic versioning (1.0.0)
- Marketing consent: Schema supports it but not currently needed
