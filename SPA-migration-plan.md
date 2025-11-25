# Dutypark SPA 전환 마스터 플랜 (Strangler Fig)

> 기존 Thymeleaf+Vue 혼합 프론트를 점진적 SPA로 교체, 백엔드 안정성 유지, 쿠키+Bearer 병행 인증

---

## 마이그레이션 진행 상태

| Phase | 상태 | 설명 |
|-------|------|------|
| Phase 0 | ✅ 완료 | 준비/조사 |
| Phase 1 | ✅ 완료 | 인증/플랫폼 기반 (Bearer + 쿠키 병행) |
| Phase 2 | ✅ 완료 | SPA 골격 (Vite + Vue 3 + Pinia + Tailwind) |
| Phase 3 | ✅ 완료 | 도메인별 Strangler |
| Phase 4 | 🔄 진행중 | 수렴/정리 |

---

## 기능 완료 현황

### 완료율 요약

| 영역 | Thymeleaf 기능 | SPA 구현 | 완료율 |
|------|---------------|----------|--------|
| 인증/로그인 | 4개 | 4개 | **100%** |
| 대시보드 | 6개 | 6개 | **100%** |
| 근무 달력 | 11개 | 11개 | **100%** |
| 팀 관리 | 6개 | 6개 | **100%** |
| 회원 설정 | 6개 | 6개 | **100%** |
| 관리자 | 5개 | 5개 | **100%** |
| **전체** | **38개** | **38개** | **100%** |

### 기능 동등성 검증 결과

Thymeleaf에만 있고 SPA에 없는 기능: **없음**

모든 핵심 기능이 SPA에 구현됨:
- ✅ D-Day localStorage 선택 유지 (`togglePinnedDDay`)
- ✅ 관리자 탭 (AppFooter에서 `isAdmin` 체크)
- ✅ 첨부파일 업로드/조회 (FileUploader, AttachmentGrid)
- ✅ 함께보기 (OtherDutiesModal)
- ✅ 일정 태깅 (DayDetailModal)
- ✅ Todo 드래그 정렬 (TodoOverviewModal + SortableJS)
- ✅ 팀 삭제 (TeamManageView - `isAppAdmin` 조건)
- ✅ 관리자 비밀번호 변경 (AdminDashboardView)

---

## 의도적인 정책 차이

### 팀 삭제 권한

| 버전 | 권한 | 설명 |
|------|------|------|
| Thymeleaf | `isAdmin` | 팀 관리자도 삭제 가능 |
| **SPA** | `isAppAdmin` | **앱 관리자만 삭제 가능** |

SPA 정책이 더 엄격함 - 팀 삭제는 중요 작업이므로 의도적 강화

---

## 작업 체크리스트

### Phase 0-2: 기반 작업 ✅

- [x] 컨트롤러/템플릿 인벤토리 작성
- [x] 인증/라우팅 설계, Tailwind 기반 디자인 토큰
- [x] 디자인 퍼블리싱 (PC/모바일 반응형)
- [x] Authorization 헤더 Bearer 지원 추가 (쿠키 방식 유지)
- [x] CORS/CSRF 재구성, Refresh API 정비
- [x] 퍼블리싱 화면에 API 클라이언트 연결, 토큰 슬라이딩/리프레시 처리

### Phase 3: 도메인별 API 연동 ✅

- [x] 대시보드 API 연동 (내 정보, 친구 관리, 핀/가족)
- [x] 근무 달력 API 연동 (조회, 편집, 배치 수정, 엑셀 업로드, 함께보기)
- [x] Todo API 연동 (CRUD, 드래그 정렬, 완료/재오픈)
- [x] 팀/회원 설정 API 연동
- [x] Admin API 연동 (통계, 회원목록, 팀 관리)
- [x] 일정 첨부파일 업로드 연동 (FileUploader, DayDetailModal)
- [x] 모바일 반응형 최적화 (iPhone Pro 390x844)
- [x] 첨부파일 그리드 및 이미지 뷰어 (AttachmentGrid, ImageViewer)
- [x] SSO 가입 플로우 (이용약관, 폼 제출, 성공페이지, Bearer 토큰 API)
- [x] DutyView 공휴일 표시 UI
- [x] DutyView 엑셀 배치 업로드 (SweetAlert2 파일 선택)
- [x] DutyView 한달 일괄 수정 (SweetAlert2 근무유형 선택)
- [x] DutyView 함께보기 내 근무 토글 (OtherDutiesModal)
- [x] TeamManageView 팀 삭제 API 연결 (adminApi.deleteTeam)
- [x] LoginView 비밀번호 maxlength (maxlength=16)
- [x] DDayModal 빠른 날짜 버튼 (+7일, +30일, 리셋)

### Phase 4: 수렴/정리 🔄

- [x] 기능 동등성 검증 (Gap Analysis)
- [ ] 전환된 경로의 Thymeleaf 뷰 제거
- [ ] SPA 정적 서빙 및 `/api/**` 네임스페이스 분리
- [ ] 문서/런북 업데이트

### P2 - 향후 개선 (신규 기능)

- [ ] TeamManageView 팀 설명 편집 기능 (백엔드 필요)

---

## 프론트엔드 구조

```
frontend/
├── src/
│   ├── api/                    # 10개 API 모듈
│   │   ├── client.ts           # Axios 인터셉터, 토큰 관리, 401 자동 갱신
│   │   ├── auth.ts             # 인증 (Bearer 토큰, 로그아웃, 비밀번호)
│   │   ├── admin.ts            # 관리자 API (별도 baseURL: /admin/api)
│   │   ├── dashboard.ts        # 대시보드 집계
│   │   ├── duty.ts             # 근무 캘린더
│   │   ├── todo.ts             # 할일 CRUD + 정렬
│   │   ├── schedule.ts         # 일정 CRUD + 태그 + 검색
│   │   ├── member.ts           # 회원/친구/D-Day/세션
│   │   ├── team.ts             # 팀 관리
│   │   └── attachment.ts       # 첨부파일 세션/유틸리티
│   ├── components/             # 15개 컴포넌트
│   │   ├── common/             # FileUploader, YearMonthPicker, AttachmentGrid, ImageViewer
│   │   ├── duty/               # DayDetailModal, TodoAddModal, TodoDetailModal, TodoOverviewModal,
│   │   │                       # DDayModal, ScheduleDetailModal, OtherDutiesModal, SearchResultModal
│   │   └── layout/             # AppLayout, AppHeader, AppFooter
│   ├── composables/            # useSwal, useKakao
│   ├── stores/auth.ts          # Pinia 인증 스토어
│   ├── views/                  # 12개 뷰
│   │   ├── auth/               # LoginView, OAuthCallbackView, SsoSignupView, SsoCongratsView
│   │   ├── dashboard/          # DashboardView
│   │   ├── duty/               # DutyView
│   │   ├── member/             # MemberView
│   │   ├── team/               # TeamView, TeamManageView
│   │   ├── admin/              # AdminDashboardView, AdminTeamListView
│   │   └── NotFoundView.vue
│   ├── types/index.ts          # 50+ TypeScript 타입
│   └── style.css               # Tailwind + 디자인 토큰
└── vite.config.ts              # 프록시: /api → localhost:8080
```

---

## Thymeleaf 템플릿 인벤토리 (제거 대상)

총 27개 템플릿 파일, 모두 SPA 대체 완료

| 분류 | 파일 수 | SPA 대체 |
|------|--------|---------|
| 레이아웃 | 3개 | AppLayout, AppHeader, AppFooter |
| 인증 | 4개 | LoginView, SsoSignupView, SsoCongratsView |
| 대시보드 | 1개 | DashboardView |
| 근무 달력 | 16개 | DutyView + 8개 모달 컴포넌트 |
| 팀 | 2개 | TeamView, TeamManageView |
| 관리자 | 2개 | AdminDashboardView, AdminTeamListView |
| 오류 | 1개 | NotFoundView |

---

## SPA 라우터 구성

| 경로 | 뷰 | 인증 | 비고 |
|------|------|------|------|
| `/` | DashboardView | 선택 | 비로그인시 소개 페이지 |
| `/auth/login` | LoginView | 게스트 전용 | - |
| `/auth/sso-signup` | SsoSignupView | 선택 | - |
| `/auth/sso-congrats` | SsoCongratsView | 필수 | - |
| `/auth/oauth-callback` | OAuthCallbackView | 선택 | - |
| `/duty/:id` | DutyView | 선택 | 가시성 체크 |
| `/member` | MemberView | 필수 | - |
| `/team` | TeamView | 필수 | - |
| `/team/manage/:teamId` | TeamManageView | 필수 | 권한 체크 |
| `/admin` | AdminDashboardView | 관리자 | - |
| `/admin/teams` | AdminTeamListView | 관리자 | - |
| `/:pathMatch(.*)*` | NotFoundView | - | 404 |

---

## 주요 API 매핑

### 인증 (`/api/auth`)

| 엔드포인트 | SPA 함수 | 설명 |
|-----------|---------|------|
| `POST /token` | `authApi.loginWithToken()` | Bearer 로그인 |
| `POST /refresh` | `authApi.refresh()` | 토큰 갱신 |
| `PUT /password` | `authApi.changePassword()` | 비밀번호 변경 |
| `GET /status` | `authApi.getStatus()` | 로그인 상태 |
| `POST /sso/signup/token` | `authApi.ssoSignupWithToken()` | SSO 가입 |

### 근무 (`/api/duty`)

| 엔드포인트 | SPA 함수 | 설명 |
|-----------|---------|------|
| `GET /` | `dutyApi.getDuties()` | 월별 근무 조회 |
| `GET /others` | `dutyApi.getOtherDuties()` | 함께보기 |
| `PUT /change` | `dutyApi.updateDuty()` | 근무 변경 |
| `PUT /batch` | `dutyApi.batchUpdateDuty()` | 한달 일괄 |
| `POST /api/duty_batch` | `dutyApi.uploadDutyBatch()` | 엑셀 업로드 |

### 일정 (`/api/schedules`)

| 엔드포인트 | SPA 함수 | 설명 |
|-----------|---------|------|
| `GET /` | `scheduleApi.getSchedules()` | 일정 조회 |
| `POST /` | `scheduleApi.saveSchedule()` | 생성/수정 |
| `DELETE /{id}` | `scheduleApi.deleteSchedule()` | 삭제 |
| `GET /{id}/search` | `scheduleApi.searchSchedules()` | 검색 |
| `POST /{id}/tags/{friendId}` | `scheduleApi.tagFriend()` | 태그 추가 |

### Todo (`/api/todos`)

| 엔드포인트 | SPA 함수 | 설명 |
|-----------|---------|------|
| `GET /` | `todoApi.getActiveTodos()` | 진행중 |
| `GET /completed` | `todoApi.getCompletedTodos()` | 완료 |
| `POST /` | `todoApi.createTodo()` | 생성 |
| `PUT /{id}` | `todoApi.updateTodo()` | 수정 |
| `PATCH /position` | `todoApi.updatePositions()` | 순서 변경 |
| `PATCH /{id}/complete` | `todoApi.completeTodo()` | 완료 처리 |
| `PATCH /{id}/reopen` | `todoApi.reopenTodo()` | 재오픈 |

### 팀 (`/api/teams`)

| 엔드포인트 | SPA 함수 | 설명 |
|-----------|---------|------|
| `GET /my` | `teamApi.getMyTeamSummary()` | 내 팀 요약 |
| `GET /shift` | `teamApi.getShift()` | 근무별 멤버 |
| `GET /schedules` | `teamApi.getTeamSchedules()` | 팀 일정 |
| `GET /manage/{id}` | `teamApi.getTeamForManage()` | 팀 관리 정보 |

### 관리자 (`/admin/api`)

| 엔드포인트 | SPA 함수 | 설명 |
|-----------|---------|------|
| `GET /members-all` | `adminApi.getAllMembers()` | 전체 회원 |
| `GET /refresh-tokens` | `adminApi.getAllRefreshTokens()` | 전체 세션 |
| `GET /teams` | `adminApi.getTeams()` | 팀 목록 |
| `POST /teams` | `adminApi.createTeam()` | 팀 생성 |
| `DELETE /teams/{id}` | `adminApi.deleteTeam()` | 팀 삭제 |

---

## SPA 개선 사항 (Thymeleaf 대비)

1. **TypeScript 타입 안전성**: 50+ 타입 정의로 컴파일 타임 에러 검출
2. **반응형 개선**: Tailwind CSS + 모바일 최적화 (iPhone Pro 390x844)
3. **가시성 옵션 확장**: PUBLIC/FRIENDS/FAMILY/PRIVATE (4단계, Thymeleaf는 3단계)
4. **통계 대시보드**: AdminDashboardView에 실시간 통계 카드 추가
5. **이미지 뷰어**: ImageViewer 컴포넌트로 라이트박스 기능 추가
6. **비밀번호 검증 강화**: 8자 이상, 현재 비밀번호 확인 필수
7. **팀 삭제 권한 강화**: 앱 관리자만 삭제 가능 (더 안전)

---

## Phase 4 세부 작업

### 4.1 SPA 정적 서빙 (프로덕션)

**nginx 설정 변경:**
```nginx
# SPA 정적 파일
location / {
    root /usr/share/nginx/html;
    try_files $uri $uri/ /index.html;
}

# API 프록시
location /api/ {
    proxy_pass http://app:8080;
}

location /admin/api/ {
    proxy_pass http://app:8080;
}
```

### 4.2 Thymeleaf 뷰 제거

제거 순서 (의존성 역순):
1. 모달 템플릿 (`duty/modals/*`)
2. 페이지 파편 (`duty/*.html` 제외 duty.html)
3. 메인 페이지 (`dashboard.html`, `duty/duty.html`, 등)
4. 레이아웃 (`layout/*`)
5. 레거시 JS (`static/js/duty/*`)

### 4.3 문서/런북

1. README.md - 프론트엔드 빌드 방법 추가
2. CLAUDE.md - SPA 관련 섹션 추가
3. 배포 가이드 업데이트

---

## 로컬 개발

```bash
# 백엔드
./gradlew bootRun  # http://localhost:8080

# 프론트엔드
cd frontend
npm run dev        # http://localhost:5173
npm run build      # dist/ 생성
```

테스트 계정: `test@duty.park / 12345678`
