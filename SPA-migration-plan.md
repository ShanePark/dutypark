# Dutypark SPA 전환 마스터 플랜 (Strangler Fig)

- 목표: 기존 Thymeleaf+Vue 혼합 프론트를 점진적 SPA로 교체, 백엔드 안정성 유지, 쿠키+Bearer 병행 인증.

## Phase 0 — 준비/조사
- 컨트롤러/템플릿 인벤토리: 경로, HTTP 메서드, 권한, 뷰 매핑, 모델 필드, 사용 JS 수집.
- 인증 토폴로지 설계: 쿠키 유지 + Bearer 병행, CORS/CSRF 정책 확정, Refresh 흐름 다이어그램화.
- 라우팅 경계: `/api/**`·`/auth/**`·`/docs/**`만 백엔드, SPA는 정적 호스팅(별 도메인 또는 리버스 프록시).
- 공용 기술 스택 결정: SPA 프레임워크(Vite+Vue3 등), API 클라이언트 패턴, 디자인 토큰.
- 로컬 계정/환경: 백엔드는 항상 `localhost:8080`에서 띄우고, 테스트 로그인 계정 `test@duty.park / 12345678` 사용 가능.

## Phase 1 — 인증/플랫폼 기반
- Bearer 지원: JWT 필터/리졸버가 Authorization 헤더도 수용(Claims 동일).
- Refresh API화: 헤더/쿠키 모두 허용, 회전 로직 기존 유지, 401/403 에러 코드 정규화.
- Kakao OAuth: 콜백 후 SPA 리다이렉트 전략(프래그먼트 토큰 또는 1회성 code-exchange API).
- CORS/CSRF: Origin 화이트리스트, credentials 여부 명확; `/api/**`는 stateless CSRF 비활성 또는 헤더 토큰.
- API 네임스페이스: `/api/v1/**` 등으로 템플릿 엔드포인트와 분리.

## Phase 2 — SPA 골격
- 별도 프런트 패키지 초기화(Vite 빌드, dev/prod env).
- API 클라이언트: 인터셉터로 Access 갱신, 공통 에러 핸들링, 슬라이딩 토큰 대응.
- 라우터: 대시보드/일정/당직/투두/멤버/팀 경로 설계, 404/권한 에러 페이지.
- 상태 관리: 전역(인증/유저/권한) 최소화, 도메인 데이터는 쿼리 캐시 활용.
- 디자인 시스템 초안: 공통 버튼/폼/모달/테이블, 테마 변수 정의.
- 프론트 작업 흐름: HTML/CSS 퍼블리싱을 먼저 더미 데이터로 완성하고 눈으로 확인한 뒤 실제 API 연동을 단계적으로 연결.

## Phase 3 — 도메인별 Strangler (저위험 → 고위험)
1) 읽기 전용/간단 리스트: 공휴일·팀·태그 등.  
2) 투두 보드: 리스트/드래그/완료·재오픈 → API 계약 확정.  
3) 당직 캘린더: 조회 → 생성/수정 → 엑셀 업로드는 마지막(파서/검증 주의).  
4) 일정: 조회 → 생성/수정 → 첨부 업로드(세션/썸네일) → AI 파싱 트리거.  
5) 대시보드: 종합 데이터(내 것+친구) 전환.  
- 각 절개 시: 템플릿 컨트롤러를 JSON API로 승격 또는 병행 엔드포인트 제공, DTO/검증/에러 메시지 통일, 기존 Vue 스니펫을 SPA 컴포넌트로 이전.
- 라우팅 스위치: nginx/백엔드에서 경로 단위로 SPA 우선, 미완 영역은 기존 페이지로 포워딩.

## Phase 4 — 수렴/정리
- 전환 완료된 경로의 Thymeleaf 뷰 제거, 시큐리티/라우팅 정리.
- 정적 자산(`/static/js/duty` 등) 불용 번들 제거.
- 문서화: 새 API 스펙, 인증 플로우, 에러 코드, 운영 런북(CORS/토큰 만료/슬랙 알림).

## 엔드포인트 조사 절차
- `src/main/java/**/controller` 전수 스캔: 경로/메서드/권한/예외.
- `templates/` 뷰가 참조하는 컨트롤러·모델 필드 역추적 → 필요한 API 스키마 도출.
- 업로드/썸네일/AI 파싱 엔드포인트 별도 표기(세션/큐/트랜잭션 고려).
- 인증 훅: 필터/`@Login` 리졸버 흐름 정리 → SPA 인증 모듈 요구사항 반영.

## 인증 병행 체크리스트
- Access 검증: 쿠키 우선, 없으면 Bearer; Claims 동일.
- Refresh: 쿠키/Bearer 모두 허용, 회전 시 세션 무효화 유지.
- 에러: 401/403 명확 분리, 코드 일관성 확보(리다이렉트 없이 처리 가능).
- Kakao OAuth: 콜백 후 SPA 안전 전달 방식 결정.
- CORS/CSRF: Origin·credentials 명시, `/api/**`는 stateless CSRF 정책.

## 릴리스/롤백 전략
- 경로별 플래그: “SPA 우선/기존 우선” 토글을 백엔드에 마련.
- 라우팅 플래그만 변경해 기존 템플릿으로 복귀 가능하게 설계.

## 다음 액션 제안
1) 컨트롤러·템플릿 매핑 인벤토리 작성(경로/권한/모델/JS).  
2) Bearer 병행 인증 설계안 확정(CORS/CSRF/Refresh 다이어그램).  
3) SPA 리포/빌드 파이프라인 초기화(Vite, 라우터, API 클라이언트, 디자인 토큰).  
4) 첫 절개 대상(읽기 전용 뷰) 선정, 라우팅 스위치 방식 결정.

## 로컬 개발 메모
- 백엔드는 항상 `http://localhost:8080`에서 실행.
- 로그인 테스트 계정: `test@duty.park / 12345678`.
- 프론트 개발 시 Playwright MCP로 같은 백엔드에 접속해 기존 화면과 신구 UI를 나란히 비교하며 최대한 동일 동작을 맞춘다.

## 전체 작업 순서 및 체크리스트
- [x] 준비: 컨트롤러/템플릿 인벤토리 작성, 인증/라우팅 설계, Tailwind 기반 디자인 토큰 초안 마련. ✅ 2024-11-24
- [x] 디자인 퍼블리싱(병렬 가능): ✅ 2024-11-24
  - [x] 기존 CSS/Bootstrap/jQuery 의존 제거, Tailwind만 사용해 HTML/CSS 퍼블리싱.
  - [x] 더미 데이터로 PC/모바일 UI 구성, 현재 형태 최대한 유지.
  - [x] Playwright MCP로 기존 화면과 신규 퍼블리싱 화면을 동일 백엔드(`http://localhost:8080`, 계정 `test@duty.park / 12345678`)에 붙여 시각/동작 비교.
- [x] 백엔드 SPA 동시 지원: ✅ 2024-11-24
  - [x] Authorization 헤더 Bearer 지원 추가(쿠키 방식 유지).
  - [x] CORS/CSRF 재구성(쿠키/헤더 병행), Refresh API 정비.
  - [ ] SPA 정적 서빙 및 `/api/**` 네임스페이스 분리, 라우팅 플래그로 신구 전환 가능하게.
- [x] 프론트 실제 연동 (인증): ✅ 2024-11-24
  - [x] 퍼블리싱된 화면에 API 클라이언트 연결, 인터셉터로 토큰 슬라이딩/리프레시 처리.
  - [x] 도메인별 Strangler 순서대로 기능 연결: 대시보드, 근무 달력, Todo, 팀/회원 설정 ✅ 2024-11-24
  - [ ] 일정 첨부파일 업로드/AI 파싱 연동
  - [ ] 연결 후 Playwright MCP로 기존 대비 UX/동작 재검증.
- [ ] 정리: 전환된 경로의 Thymeleaf 뷰/불용 자산 제거, 문서/런북 업데이트.

## 병렬 진행 메모
- 디자인 퍼블리싱 트랙: Tailwind-only UI, 더미 데이터로 PC/모바일 대응, Playwright로 시각 비교.
- 백엔드 트랙: Bearer 병행·CORS/CSRF 정비·라우팅 플래그 구현.
- 연동 트랙: 퍼블리싱 결과에 API를 단계적으로 접목, 각 단계마다 Playwright로 회귀 확인.

---

## 작업 로그

### 2024-11-24: Phase 0 준비 완료

#### 1. 컨트롤러 인벤토리 (28개)

| 모듈 | API 컨트롤러 | 뷰 컨트롤러 | 주요 기능 |
|------|-------------|------------|----------|
| Attachment | 2 | - | 파일 업로드/다운로드/썸네일, 세션 관리 |
| Schedule | 1 | - | 일정 CRUD, 태그, 검색 |
| Duty | 1 | 1 | 근무 조회/변경, 배치 업로드 |
| Todo | 1 | - | 할일 CRUD, 드래그 정렬, 완료/재오픈 |
| Team | 4 | 1 | 팀 정보, 멤버/관리자 관리, 근무유형, 일정 |
| Member | 4 | 1 | 친구, D-Day, 리프레시토큰, 회원설정 |
| Dashboard | 1 | - | 내 정보 + 친구 정보 조회 |
| Holiday | 1 | - | 공휴일 API (캐시) |
| Security | 2 | 1 | 로그인/로그아웃, Kakao OAuth, SSO |
| Common | 1 | 1 | 달력 API, 문서 포워딩 |
| Admin | 1 | 1 | 관리자 전용 (회원/팀 관리) |

#### 2. 템플릿 인벤토리 (11개 주요)

| 템플릿 | 라우트 | Vue.js | 주요 라이브러리 |
|--------|--------|--------|----------------|
| dashboard.html | GET / | O | SortableJS |
| duty/duty.html | GET /duty/{id} | O | SortableJS, Uppy, SweetAlert2 |
| member/login.html | GET /auth/login | O | Kakao SDK |
| member/member.html | GET /member | O | Kakao SDK, SweetAlert2 |
| team/team-my.html | GET /team | O | SweetAlert2 |
| team/team-manage.html | GET /team/manage/{id} | O | Pickr, SweetAlert2 |
| admin/admin-home.html | GET /admin | O | Day.js |
| admin/team/team-list.html | GET /admin/team | O | SweetAlert2 |

#### 3. 인증 시스템 분석

**현재 구조:**
- JWT 쿠키 기반 (HttpOnly, SameSite=Lax)
- Access Token: 30분 (쿠키명: SESSION)
- Refresh Token: 7일, 슬라이딩 방식 (쿠키명: REFRESH_TOKEN)
- Kakao OAuth 지원 (SSO 회원가입 흐름)

**Bearer 병행을 위한 변경 제안:**
- `JwtAuthFilter`: Authorization 헤더 우선 검사 → 없으면 쿠키 검사
- `/api/auth/refresh` 엔드포인트 추가 (Bearer 토큰 응답)
- 로그인 응답에 JWT 토큰 포함 옵션

#### 4. SPA 프로젝트 생성 (`frontend/`)

```
frontend/
├── src/
│   ├── api/
│   │   ├── client.ts      # Axios 인터셉터, 401 핸들링
│   │   └── auth.ts        # 인증 API (login, logout, getStatus)
│   ├── components/
│   │   └── layout/
│   │       ├── AppLayout.vue
│   │       ├── AppHeader.vue
│   │       └── AppFooter.vue
│   ├── composables/       # (예정) 재사용 로직
│   ├── router/
│   │   └── index.ts       # Vue Router, 인증 가드
│   ├── stores/
│   │   └── auth.ts        # Pinia 인증 스토어
│   ├── types/
│   │   └── index.ts       # TypeScript 타입 정의
│   ├── views/
│   │   ├── auth/          # LoginView, SsoSignupView
│   │   ├── dashboard/     # DashboardView
│   │   ├── duty/          # DutyView
│   │   ├── member/        # MemberView
│   │   ├── team/          # TeamView, TeamManageView
│   │   └── NotFoundView.vue
│   ├── style.css          # Tailwind + 디자인 토큰
│   ├── main.ts
│   └── App.vue
├── vite.config.ts         # 프록시: /api → localhost:8080
├── tsconfig.app.json      # 경로 별칭 @/
└── package.json
```

**의존성:**
- Vue 3, Vue Router 4, Pinia
- Axios, Day.js, SweetAlert2
- Tailwind CSS 4 (@tailwindcss/vite)

#### 5. 디자인 토큰 (`src/style.css`)

**색상:**
- Primary: #0d6efd (파랑)
- Success: #198754 (초록)
- Danger: #dc3545 (빨강)
- Warning: #ffc107 (노랑)
- Kakao: #fee500
- 일요일: 빨강, 토요일: 파랑

**컴포넌트 클래스:**
- `.btn`, `.btn-primary`, `.btn-kakao` 등
- `.card`, `.card-body`
- `.form-control`, `.form-label`
- `.day-grid`, `.day-cell`, `.day-of-week`
- `.todo-item`, `.friend-card`
- `.attachment-gallery`, `.attachment-tile`

#### 6. 실행 확인

```bash
cd frontend
npm run dev   # http://localhost:3000
npm run build # dist/ 생성 확인
```

- Vite 개발 서버: `/api/*` → `localhost:8080` 프록시
- 빌드 성공 (TypeScript 오류 없음)

---

### 2024-11-24: 디자인 퍼블리싱 완료

#### 1. 기존 화면 캡처
- Playwright로 localhost:8080 접속
- 비로그인 대시보드, 로그인 페이지, 로그인 후 대시보드, 근무 달력 캡처
- 스크린샷 저장: `.playwright-mcp/screenshots/`

#### 2. 퍼블리싱 완료 페이지

| 페이지 | 파일 | 주요 기능 |
|--------|------|----------|
| 대시보드 (비로그인) | `DashboardView.vue` | 소개, 주요 기능 목록, 로그인 버튼 |
| 대시보드 (로그인) | `DashboardView.vue` | 오늘 정보, 근무, 일정, 친구 목록 그리드 |
| 로그인 | `LoginView.vue` | 이메일/비밀번호, 아이디 저장, 카카오 로그인 |
| 근무 달력 | `DutyView.vue` | Todo 리스트, 월 컨트롤, 7열 그리드, D-Day |

#### 3. 반응형 확인
- PC (1280x800): 정상
- 모바일 (375x812): 정상
- Tailwind 반응형 클래스 적용: `sm:`, `md:` breakpoints

#### 4. 주요 변경 파일
```
frontend/src/views/
├── auth/LoginView.vue          # 로그인 폼, 카카오 버튼
├── dashboard/DashboardView.vue # 게스트/로그인 분기, 친구 그리드
└── duty/DutyView.vue           # 7열 달력, Todo, D-Day
```

---

### 2024-11-24: 백엔드 SPA 동시 지원 및 인증 연동 완료

#### 1. 백엔드 변경사항

**JwtAuthFilter.kt**
- Authorization Bearer 헤더 지원 추가
- 헤더 우선 → 쿠키 폴백 순서로 토큰 검사
- `extractBearerToken()` 메서드 추가

**SecurityConfig.kt**
- CORS 설정 추가 (`/api/**` 경로)
- `dutypark.cors.allowed-origins` 환경변수로 Origin 설정 가능 (기본: `http://localhost:3000`)
- `corsConfigurationSource()` Bean 추가

**AuthController.kt - 새 API**
- `POST /api/auth/token`: Bearer 토큰 로그인 (JSON body로 토큰 반환)
- `POST /api/auth/refresh`: Refresh token으로 새 Access token 발급

**AuthService.kt**
- `getTokenResponse()`: 로그인 후 TokenResponse 반환
- `refreshAccessToken()`: refresh token으로 access token 갱신

**TokenResponse.kt (신규)**
```kotlin
data class TokenResponse(
    val accessToken: String,
    val refreshToken: String,
    val expiresIn: Long,
    val tokenType: String = "Bearer"
)
```

#### 2. 프론트엔드 변경사항

**api/client.ts**
- `tokenManager`: localStorage 기반 토큰 관리
- Request interceptor: Authorization Bearer 헤더 자동 추가
- Response interceptor: 401 시 자동 토큰 갱신, 실패 시 로그인 페이지 리다이렉트

**api/auth.ts**
- `loginWithToken()`: Bearer 토큰 방식 로그인
- `refresh()`: 토큰 갱신
- `hasTokens()`: 토큰 존재 여부 확인

**stores/auth.ts**
- Bearer 토큰 방식 로그인으로 변경
- `clearAuth()` 메서드 추가

**types/index.ts**
- `TokenResponse` 인터페이스 추가

#### 3. 테스트 결과
- Playwright MCP로 `http://localhost:3000/auth/login` 접속
- 테스트 계정 (`test@duty.park / 12345678`)으로 로그인 성공
- 대시보드 정상 표시 확인

---

### 2024-11-24: 도메인별 API 연동 (Phase 3 진행 중)

#### 1. 새로운 API 모듈 추가 (10개)

| 파일 | 주요 기능 |
|------|----------|
| `api/client.ts` | Axios 인터셉터, Bearer 토큰 관리, 401 자동 갱신 |
| `api/dashboard.ts` | 대시보드 데이터 조회 (내 정보 + 친구 목록) |
| `api/duty.ts` | 근무 조회/변경, 월별 데이터, 배치 업데이트, 함께보기 |
| `api/todo.ts` | 할일 CRUD, 정렬, 완료/재오픈 |
| `api/schedule.ts` | 일정 CRUD, 검색, 첨부파일 연결, 태그 관리 |
| `api/member.ts` | 회원 정보, 친구 관리(핀/언핀/가족), D-Day, 리프레시 토큰 |
| `api/team.ts` | 팀 정보, 멤버/관리자 관리, 근무유형, 배치 업로드 |
| `api/attachment.ts` | 파일 업로드 세션, 첨부파일 관리, 유틸리티 |
| `api/admin.ts` | 관리자 전용 (회원/팀 관리, 통계) |
| `api/auth.ts` | Bearer 토큰 로그인, 리프레시, 비밀번호 변경 |

#### 2. 공통 컴포넌트 추가

| 컴포넌트 | 설명 |
|----------|------|
| `components/common/FileUploader.vue` | Uppy 기반 파일 업로더 (드래그앤드롭, 진행률, 세션 관리) |
| `components/common/YearMonthPicker.vue` | 연/월 선택 모달 (12개월 그리드, 년도 이동) |
| `components/duty/DayDetailModal.vue` | 일별 상세 모달 (근무유형, 일정 CRUD, 태그, 첨부파일) |
| `components/duty/TodoAddModal.vue` | 할일 생성 모달 (파일 업로드 포함) |
| `components/duty/TodoDetailModal.vue` | 할일 상세/수정/완료/재오픈/삭제 모달 |
| `components/duty/ScheduleDetailModal.vue` | 일정 상세 읽기 전용 모달 (첨부파일 갤러리) |

#### 3. 유틸리티 추가

| 파일 | 설명 |
|------|------|
| `composables/useSwal.ts` | SweetAlert2 래퍼 (confirm, toast, error/success/warning 모달) |
| `types/index.ts` | 전체 타입 정의 (인증, 도메인, 페이지네이션 등 50+ 타입) |

#### 4. 뷰 API 연동 완료

| 뷰 | 연동 내용 |
|----|----------|
| `DashboardView.vue` | 내 정보, 오늘 근무/일정, 친구 목록/검색/핀/가족 API 연동 |
| `DutyView.vue` | 월별 근무 달력, Todo 전체 CRUD, 일정 CRUD, D-Day, 함께보기 연동 |
| `MemberView.vue` | 회원 정보, 친구 관리, D-Day, 세션 관리, 비밀번호 변경 연동 |
| `TeamView.vue` | 팀 정보, 멤버 목록, 팀 일정 CRUD 연동 |
| `TeamManageView.vue` | 팀 관리, 멤버/관리자, 근무유형 CRUD, 배치 업로드 연동 |
| `AdminDashboardView.vue` | 통계, 회원 목록, 세션 관리, 비밀번호 초기화 연동 |
| `AdminTeamListView.vue` | 팀 목록, 생성, 검색 연동 |

#### 5. 모달 컴포넌트 API 연동

| 컴포넌트 | 연동 내용 |
|----------|----------|
| `DayDetailModal.vue` | 일별 상세 조회, 근무유형 변경, 일정 CRUD, 태그 관리, 첨부파일 |
| `TodoAddModal.vue` | 할일 생성 API, 파일 업로드 세션 |
| `TodoDetailModal.vue` | 할일 상세/수정/삭제/완료/재오픈 API |
| `ScheduleDetailModal.vue` | 일정 상세 읽기 전용, 첨부파일 갤러리 |

#### 6. 타입 정의 확장 (`types/index.ts`)

- Authentication: `LoginMember`, `LoginDto`, `LoginResponse`, `TokenResponse`
- Dashboard: `DashboardMyDetail`, `DashboardFriendDetail`, `DashboardMyInfo`, `DashboardFriendsInfo`
- Duty: `Duty`, `DutyType`, `DutyCalendarDay`, `DutyCalendarResponse`
- Todo: `Todo`, `TodoStatus` (ACTIVE | COMPLETED)
- Schedule: `Schedule`, `ScheduleTag`, `TeamScheduleDto`
- Member: `Member`, `Friend`, `FriendDto`, `FriendRequest`, `DDay`, `DDayDto`
- Team: `Team`, `TeamDto`, `DutyTypeDto`, `TeamMemberDto`, `DutyBatchTemplateDto`
- Admin: `AdminMember`, `RefreshToken`, `RefreshTokenDto`, `UserAgentInfo`
- Attachment: `Attachment`, `AttachmentDto`, `NormalizedAttachment`
- Common: `Page<T>`, `PageResponse<T>`, `CalendarVisibility`, `AttachmentContextType`

#### 7. 백엔드 변경사항

**LoginMember.kt**
- `teamId` 필드 추가 (SPA에서 팀 정보 접근용)

**JwtProvider.kt**
- JWT Claims에 `teamId` 추가

**MemberController.kt**
- `GET /api/members/me`: 현재 로그인 사용자 정보 조회
- `GET /api/members/{memberId}`: 특정 회원 정보 조회 (visibility 체크)

**FriendService.kt**
- `checkVisibility(LoginMember?, Long, Boolean)`: memberId로 visibility 체크하는 오버로드 추가

#### 8. 의존성 추가 (`package.json`)

- `@uppy/core`, `@uppy/dashboard`, `@uppy/xhr-upload` - 파일 업로더
- `sortablejs`, `@types/sortablejs` - 드래그앤드롭 정렬
- `@vueuse/core` - Vue 유틸리티 컴포저블
- `lucide-vue-next` - 아이콘 라이브러리
- `sweetalert2` - 알림/확인 모달
- `pickr` - 컬러 피커 (근무유형 색상 선택)

---

### 2024-11-24: DashboardView 친구 관리 API 연동 완료

#### 연동 완료 함수 (7개)

| 함수 | 연동 API | 설명 |
|------|---------|------|
| `pinFriend()` | `PATCH /api/friends/pin/{id}` | 친구 고정 |
| `unpinFriend()` | `PATCH /api/friends/unpin/{id}` | 친구 고정 해제 |
| `acceptFriendRequest()` | `POST /api/friends/request/accept/{id}` | 친구 요청 수락 |
| `rejectFriendRequest()` | `POST /api/friends/request/reject/{id}` | 친구 요청 거절 |
| `addFamily()` | `PUT /api/friends/family/{id}` | 가족 요청 전송 |
| `unfriend()` | `DELETE /api/friends/{id}` | 친구 삭제 |
| `updateFriendsPin()` | `PATCH /api/friends/pin/order` | 친구 순서 변경 (드래그) |

---

### 다음 단계 (미완료 현황) - 2024-11-24 재분석

#### 완료된 작업
- [x] 대시보드 API 연동 ✅
- [x] 근무 달력 API 연동 ✅
- [x] Todo API 연동 ✅
- [x] 팀/회원 설정 API 연동 ✅
- [x] DashboardView 친구 관리 API 연동 ✅
- [x] AdminDashboardView API 연동 ✅ (통계, 회원목록, 비밀번호 변경 등 완료)
- [x] AdminTeamListView API 연동 ✅ (팀 목록, 생성, 검색 완료)

---

### 미구현 기능 상세 (기존 Thymeleaf 대비) - 2024-11-24 재검토

#### 1. DutyView (근무 달력) - 대부분 완료 ✅

| 기능 | 기존 코드 위치 | 상태 | 우선순위 |
|------|---------------|------|----------|
| 편집모드 - 인라인 근무유형 버튼 | `day-grid.html:79-88` | ✅ 구현됨 (배치 편집 모드) | - |
| 한번에 수정 - 배치 업데이트 모달 | `duty-table-header.js:2-57` | ✅ 구현됨 | - |
| 함께보기 API 연동 | `show-other-duties-modal.js` | ✅ 구현됨 (`getOtherDuties` API) | - |
| 일정 태그/언태그 UI | `duty.js:421-456` | ✅ 구현됨 (`DayDetailModal`) | - |
| **시간표 파일 업로드 (엑셀 배치)** | `duty-table-header.js:58-113` | ❌ 미구현 | 🟡 중간 |
| 공휴일 표시 | `day-grid.html:35-42` | ⚠️ 캘린더 API에서 받아오지만 UI 미표시 | 🟡 중간 |
| 모달 닫을 때 세션 정리 | `duty.js:505-522` | ⚠️ 부분 구현 | 🟢 낮음 |

**세부 설명:**
- **시간표 파일 업로드**: 팀별 `dutyBatchTemplate`에 따른 엑셀 파일 파싱 (`POST /api/duty_batch`) - TeamManageView에서는 구현됨, DutyView에서는 미구현

#### 2. LoginView/OAuth (로그인) - 고위험 ⚠️

| 기능 | 기존 코드 위치 | 상태 | 우선순위 |
|------|---------------|------|----------|
| **아이디 저장 (Remember Me)** | `login.html:47-49`, `AuthService.kt:91-97` | ❌ 체크박스만 있고 동작 안함 | 🔴 높음 |
| **이용약관 표시** | `sso-signup.html:19-68` | ❌ 체크박스만, 약관 내용 없음 | 🔴 높음 |
| **SSO 가입 폼 제출** | `sso-signup.html:6, 70-94` | ❌ @submit 핸들러 없음 | 🔴 높음 |
| **가입 성공 페이지** | `sso-congrats.html` | ❌ 페이지 없음 | 🔴 높음 |
| UUID 상태 관리 | `sso-signup.html:7, 81` | ❌ route params에서 읽지 않음 | 🔴 높음 |
| 비밀번호 maxlength | `login.html:17` | ❌ 없음 | 🟢 낮음 |
| 사용자명 helper text | `sso-signup.html:14-16` | ❌ 없음 | 🟡 중간 |

**세부 설명:**
- **아이디 저장**: 로그인 시 `rememberMe` 쿠키에 이메일 저장, 다음 방문 시 자동 입력
- **이용약관**: 10개 조항의 스크롤 가능한 약관 전문 표시 필요
- **SSO 가입**: `POST /api/auth/sso/signup`에 `uuid`, `username`, `term_agree` 전송

#### 3. DashboardView (대시보드) - 완료 ✅

| 기능 | 기존 코드 위치 | 상태 | 우선순위 |
|------|---------------|------|----------|
| 관리자 섹션 링크 | `dashboard.html:219-233` | ✅ AppFooter에서 관리자 메뉴 제공 | - |

**세부 설명:**
- Admin 사용자는 하단 네비게이션에서 관리자 메뉴 접근 가능

#### 4. TeamManageView (팀 관리) - 대부분 완료 ✅

| 기능 | 기존 코드 위치 | 상태 | 우선순위 |
|------|---------------|------|----------|
| 배치 업로드 (엑셀) | `team-manage.html:763-862` | ✅ 구현됨 | - |
| 근무유형 CRUD | - | ✅ 구현됨 (색상 선택 포함) | - |
| **팀 삭제** | `team-manage.html:950-979` | ❌ 백엔드 API 미구현 (경고만 표시) | 🟡 중간 |
| 팀 설명 편집 | `team-manage.html:14-16` | ❌ 읽기전용 | 🟢 낮음 |

#### 5. MemberView (회원 설정) - 완료 ✅

- 모든 기능 구현됨
- 비밀번호 변경 (현재 비밀번호 검증 포함)
- 세션/리프레시 토큰 관리
- 친구 가시성 설정
- D-Day 관리

#### 6. AdminView (관리자) - 완료 ✅

- 통계 대시보드 (회원수, 팀수, 토큰수, 오늘 로그인)
- 회원 목록 검색 및 페이지네이션
- 세션 토큰 관리
- 비밀번호 초기화
- 팀 목록/생성/검색

---

### 우선순위별 작업 목록 - 2024-11-24 재검토

#### 🔴 P0 - 필수 (SPA 출시 전 완료 필요)

**DutyView:** (대부분 완료)
- [x] 편집모드 인라인 근무유형 버튼 구현 ✅
- [x] 한번에 수정 배치 업데이트 모달 구현 ✅
- [x] 함께보기 API 연동 ✅

**LoginView/OAuth:**
- [ ] 아이디 저장 (Remember Me) 기능 구현
- [ ] SsoSignupView 이용약관 전문 표시
- [ ] SsoSignupView 폼 제출 핸들러 구현 (UUID 포함)
- [ ] SsoCongratsView 가입 성공 페이지 생성

#### 🟡 P1 - 중요 (출시 후 빠른 패치)

- [ ] DutyView 시간표 파일 업로드 (엑셀 배치) - 개인 캘린더에서
- [ ] DutyView 공휴일 표시 UI (API 연동 완료, UI 미표시)
- [ ] TeamManageView 팀 삭제 기능 (백엔드 API 필요)
- [ ] SsoSignupView 사용자명 helper text 추가

#### 🟢 P2 - 개선 (추후 진행)

- [ ] LoginView 비밀번호 maxlength 추가
- [ ] TeamManageView 팀 설명 편집 기능
- [ ] MemberView 카카오 연동 해제 기능 (신규)
- [ ] 모달 닫을 때 첨부파일 세션 정리 개선

---

### 기타 미완료 작업

- [x] 일정 첨부파일 업로드 연동 ✅ (FileUploader, DayDetailModal에서 동작)
- [ ] AI 파싱 연동 (백엔드 구현됨, 프론트 UI 미구현)
- [ ] Playwright MCP로 기존 대비 UX/동작 재검증
- [ ] 전환된 경로의 Thymeleaf 뷰 제거
- [ ] SPA 정적 서빙 및 `/api/**` 네임스페이스 분리

---

### 2024-11-24: 코드 분석 요약

#### 프론트엔드 구조 현황

```
frontend/
├── src/
│   ├── api/                    # 10개 API 모듈
│   │   ├── client.ts           # Axios 인터셉터, 토큰 관리
│   │   ├── auth.ts             # 인증 (Bearer 토큰)
│   │   ├── admin.ts            # 관리자 API
│   │   ├── dashboard.ts        # 대시보드
│   │   ├── duty.ts             # 근무
│   │   ├── todo.ts             # 할일
│   │   ├── schedule.ts         # 일정
│   │   ├── member.ts           # 회원/친구/D-Day
│   │   ├── team.ts             # 팀
│   │   └── attachment.ts       # 첨부파일
│   ├── components/
│   │   ├── common/             # 공용 컴포넌트
│   │   │   ├── FileUploader.vue
│   │   │   └── YearMonthPicker.vue
│   │   ├── duty/               # 근무 관련 모달
│   │   │   ├── DayDetailModal.vue
│   │   │   ├── TodoAddModal.vue
│   │   │   ├── TodoDetailModal.vue
│   │   │   └── ScheduleDetailModal.vue
│   │   └── layout/             # 레이아웃
│   │       ├── AppHeader.vue
│   │       └── AppFooter.vue
│   ├── composables/
│   │   └── useSwal.ts          # SweetAlert2 래퍼
│   ├── views/                  # 7개 주요 뷰
│   │   ├── auth/
│   │   ├── dashboard/
│   │   ├── duty/
│   │   ├── member/
│   │   ├── team/
│   │   └── admin/
│   ├── types/index.ts          # 50+ 타입 정의
│   └── style.css               # Tailwind + 디자인 토큰
└── vite.config.ts              # Vite 설정 (프록시 포함)
```

#### 완료된 주요 기능

1. **인증 시스템**: Bearer 토큰 로그인, 자동 갱신, 카카오 OAuth
2. **대시보드**: 내 정보, 오늘 근무/일정, 친구 관리 (검색/핀/가족)
3. **근무 달력**: 월별 조회, 배치 수정, 함께보기, D-Day
4. **Todo**: CRUD, 드래그 정렬, 완료/재오픈, 첨부파일
5. **일정**: CRUD, 태그, 첨부파일 업로드, 검색
6. **팀**: 조회, 팀 일정, 팀 관리 (멤버/관리자/근무유형)
7. **관리자**: 통계, 회원/팀 관리, 비밀번호 초기화

#### 미완료 P0 (출시 차단)

- SSO 가입 플로우 (이용약관, 폼 제출, 성공 페이지)
- Remember Me (아이디 저장)
