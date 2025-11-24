# Dutypark SPA 전환 마스터 플랜 (Strangler Fig)

- 목표: 기존 Thymeleaf+Vue 혼합 프론트를 점진적 SPA로 교체, 백엔드 안정성 유지, 쿠키+Bearer 병행 인증.

---

## 마이그레이션 진행 상태

```
✅ Phase 0 - 준비/조사: 완료
✅ Phase 1 - 인증/플랫폼 기반: 완료 (Bearer + 쿠키 병행)
✅ Phase 2 - SPA 골격: 완료 (Vite + Vue 3 + Pinia + Tailwind)
✅ Phase 3 - 도메인별 Strangler: 97% 완료
🔄 Phase 4 - 수렴/정리: 진행 예정
```

### 완료율 요약

| 영역 | Thymeleaf 기능 | SPA 구현 | 완료율 |
|------|---------------|----------|--------|
| 인증/로그인 | 4개 | 4개 | **100%** |
| 대시보드 | 6개 | 6개 | **100%** |
| 근무 달력 | 11개 | 11개 | **100%** |
| 팀 관리 | 6개 | 6개 | **100%** |
| 회원 설정 | 7개 | 6개 | 86% |
| 관리자 | 5개 | 5개 | **100%** |
| **전체** | **39개** | **38개** | **97%** |

---

## 전체 작업 체크리스트

### Phase 0-2: 기반 작업 ✅ 완료
- [x] 컨트롤러/템플릿 인벤토리 작성, 인증/라우팅 설계, Tailwind 기반 디자인 토큰
- [x] 디자인 퍼블리싱 (Tailwind-only, PC/모바일 반응형)
- [x] Authorization 헤더 Bearer 지원 추가 (쿠키 방식 유지)
- [x] CORS/CSRF 재구성, Refresh API 정비
- [x] 퍼블리싱 화면에 API 클라이언트 연결, 토큰 슬라이딩/리프레시 처리

### Phase 3: 도메인별 API 연동 ✅ 완료
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

### Phase 4: 정리 (진행중)
- [x] Playwright MCP로 기존 대비 UX/동작 재검증
- [ ] 전환된 경로의 Thymeleaf 뷰 제거
- [ ] SPA 정적 서빙 및 `/api/**` 네임스페이스 분리
- [ ] 문서/런북 업데이트

### P2 - 향후 개선
- [ ] TeamManageView 팀 설명 편집 기능 (백엔드 필요)
- [ ] MemberView 카카오 연동 해제 기능 (백엔드 필요)

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

## 백엔드 API 매핑

### Duty API

| API명 | HTTP 메서드 | 엔드포인트 | SPA 함수 |
|-------|-----------|---------|---------|
| 근무 조회 | GET | `/api/duty` | `dutyApi.getDuties()` |
| 함께보기 | GET | `/api/duty/others` | `dutyApi.getOtherDuties()` |
| 근무 변경 | PUT | `/api/duty/change` | `dutyApi.updateDuty()` |
| 배치 업데이트 | PUT | `/api/duty/batch` | `dutyApi.batchUpdateDuty()` |
| 엑셀 업로드 | POST | `/api/duty_batch` | `dutyApi.uploadDutyBatch()` |

### Admin API

| 백엔드 엔드포인트 | SPA 함수 |
|-----------------|----------|
| `GET /admin/api/members-all` | `getAllMembers()` |
| `GET /admin/api/refresh-tokens` | `getAllRefreshTokens()` |
| `GET /admin/api/teams` | `getTeams()` |
| `POST /admin/api/teams` | `createTeam()` |
| `POST /admin/api/teams/check` | `checkTeamName()` |
| `DELETE /admin/api/teams/{id}` | `deleteTeam()` |

---

## Thymeleaf vs SPA 기능 매핑 (완료)

### DutyView

| Thymeleaf 파일 | 기능 | SPA 구현 위치 |
|---------------|------|--------------|
| `duty-table-header.js:2-57` | 한달 일괄 수정 | `DutyView.vue:showBatchUpdateModal()` |
| `duty-table-header.js:58-113` | 엑셀 배치 업로드 | `DutyView.vue:showExcelUploadModal()` |
| `show-other-duties-modal.js` | 함께보기 + 내 근무 토글 | `OtherDutiesModal.vue` |
| `day-grid.html:35-42` | 공휴일 표시 | `DutyView.vue:holidaysByDays` |
| `dday-list.js:78-92` | D-Day 빠른 날짜 버튼 | `DDayModal.vue:addDays()` |

### TeamManageView

| 기능 | Thymeleaf | SPA | 비고 |
|------|-----------|-----|------|
| 팀 정보 표시 | ✅ | ✅ | 동등 |
| 멤버 관리 | ✅ | ✅ | SPA 모바일 반응형 개선 |
| 관리자 관리 | ✅ | ✅ | 동등 |
| 근무유형 CRUD | ✅ | ✅ | 동등 (Pickr 색상 선택) |
| 배치 업로드 | ✅ | ✅ | 동등 |
| 팀 삭제 | ✅ | ✅ | 권한 차이: SPA는 `isAppAdmin`, Thymeleaf는 `isAdmin` |

---

## SPA 개선 사항 (Thymeleaf 대비)

1. **TypeScript 타입 안전성**: 50+ 타입 정의로 컴파일 타임 에러 검출
2. **반응형 개선**: Tailwind CSS + 모바일 최적화 (iPhone Pro 390x844)
3. **가시성 옵션 확장**: PUBLIC/FRIENDS/FAMILY/PRIVATE (4단계, Thymeleaf는 3단계)
4. **통계 대시보드**: AdminDashboardView에 실시간 통계 카드 추가
5. **이미지 뷰어**: ImageViewer 컴포넌트로 라이트박스 기능 추가
6. **비밀번호 검증 강화**: 8자 이상, 현재 비밀번호 확인 필수

---

## 로컬 개발 메모

- 백엔드: `http://localhost:8080`
- 프론트엔드: `http://localhost:5173`
- 테스트 계정: `test@duty.park / 12345678`

```bash
# 프론트엔드 실행
cd frontend
npm run dev   # http://localhost:5173
npm run build # dist/ 생성
```

---

## 주의사항

### 팀 삭제 권한 차이
- **SPA**: `isAppAdmin` (전체 앱 관리자만)
- **Thymeleaf**: `isAdmin` (팀 관리자도 가능)

마이그레이션 완료 후 권한 정책 통일 필요.
