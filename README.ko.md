# Dutypark

[한국어](README.ko.md) | [English](README.md)

[https://dutypark.o-r.kr](https://dutypark.o-r.kr)

<a href="#" target="_blank"><img src="https://img.shields.io/badge/Kotlin-7F52FF?style=flat-square&logo=Kotlin&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/Spring Boot-6DB33F?style=flat-square&logo=Spring-Boot&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/JPA-ED2761?style=flat-square&logo=Spring&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/MySQL-4479A1?style=flat-square&logo=MySQL&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/Vue.js-4FC08D?style=flat-square&logo=Vue.js&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/TypeScript-3178C6?style=flat-square&logo=TypeScript&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/PWA-5A0FC8?style=flat-square&logo=PWA&logoColor=white"/></a>

> **나와 소중한 사람들을 위한 소셜 캘린더**

---

## 왜 Dutypark인가요?

일정은 단순히 근무만이 아닙니다. 데이트를 계획하려는 연인, 서로의 스케줄에 맞춰야 하는 가족, 응원하는 팀의 경기 일정을 공유하는 친구들까지.

**Dutypark은 당신의 일상을 소중한 사람들과 연결합니다.** 일정을 공유하고, 함께 계획하고, 서로의 하루를 알 수 있어요.

### 누구를 위한 서비스인가요?

| 사용자 | 얻는 가치 |
|:-------|:----------|
| **가족** | 배우자, 아이들과 일정 공유 — 등하원, 가족 이벤트를 놓치지 않게 |
| **직장인** | 근무일과 연차를 관리하고, 가족에게 공유해서 언제 쉬는지 알려주기 |
| **스포츠 팬** | 응원팀 일정 관리 — 홈/원정, 경기 시간, 장소, 상대팀까지 |
| **교대근무자** | 엑셀로 근무표 업로드, 가족과 공유, 동료와 대타 조율 |
| **부모** | 어린이집 등하원, 학교 행사, 주말 일정을 한 곳에서 |

---

## 핵심 경험

### 의도를 담은 공유

모든 사람에게 모든 것을 보여줄 필요는 없습니다. Dutypark은 **네 단계의 프라이버시**를 제공합니다:

- **전체 공개** — 누구나 볼 수 있음
- **친구 공개** — 승인된 친구만 볼 수 있음
- **가족 공개** — 가장 가까운 가족에게만
- **나만 보기** — 오직 나만

일정에 친구를 태그하세요. 그들의 대시보드에 바로 나타납니다. "카톡 봤어?" 물어볼 필요 없이.

### 나만의 캘린더

- **근무 캘린더** — 색상으로 구분된 근무표, 빈 날은 자동으로 휴무 표시
- **일정 관리** — 약속, 모임, 할 일을 추가하고 AI가 시간을 자동 추출
- **투두 보드** — 드래그 앤 드롭으로 정리되는 할 일 목록
- **디데이 카운트다운** — 기념일, 마감일, 중요한 날을 잊지 않도록

### 함께 연결되기

- **대시보드** — 오늘 내 근무와 친구/가족의 일정을 한 화면에서
- **알림** — 누군가 나를 태그하거나 친구 요청을 보내면 바로 알림
- **팀 보기** — 팀 전체 근무표를 한눈에, 관리자 권한으로 설정

---

## 주요 기능

### 일정 & 공유

| 기능 | 설명 |
|:-----|:-----|
| **스마트 공개 설정** | 4단계 프라이버시 (전체/친구/가족/나만) — 일정마다 세밀하게 조절 |
| **친구 태그** | 일정에 친구를 태그하면 대시보드에 표시되고 알림 발송 |
| **가족 모드** | 혈연관계와 가장 가까운 사람들을 위한 특별한 공개 설정 |
| **엑셀 업로드** | 병원/매장 근무표 템플릿을 그대로 일괄 업로드 (SungsimCake 파서) |
| **AI 시간 파싱** | "오후 3시~5시 회의" 같은 자연어에서 비동기 Gemini 큐로 시간 자동 추출 |
| **순서 재정렬** | 같은 날의 일정을 드래그로 재정렬, 순서 저장 |

### 개인 생산성

| 기능 | 설명 |
|:-----|:-----|
| **디데이 카운트다운** | 기념일, 마감일, 중요한 날 — 공개 여부도 선택 가능 |
| **칸반 투두 보드** | 다중 상태 컬럼 (BACKLOG/TODO/DOING/DONE/CLOSED) 드래그 앤 드롭 |
| **일정 검색** | 전체 텍스트 검색으로 원하는 날짜로 바로 이동, 페이지네이션 지원 |
| **프로필 사진** | 프로필 사진 업로드 및 크롭, 자동 썸네일 생성 |
| **첨부파일** | 일정에 파일 첨부, 재개 가능한 업로드, 자동 썸네일 |

### 팀 협업

| 기능 | 설명 |
|:-----|:-----|
| **팀 캘린더** | 모든 팀원의 근무를 색상별로 한눈에 |
| **관리자 컨트롤** | 멤버 초대/제거, 근무 유형과 색상 설정 |
| **일괄 업로드 템플릿** | 엑셀 업로드를 위한 설정 가능한 배치 템플릿 (SungsimCake 형식) |
| **팀 일정** | 팀 전체에 보이는 공지사항과 이벤트 |
| **시프트 보기** | 누가 어떤 근무인지 일별로 한눈에 확인 |

### 플랫폼 & 연동

| 기능 | 설명 |
|:-----|:-----|
| **카카오 로그인** | 한 번의 클릭으로 로그인 |
| **공휴일 동기화** | 공공데이터포털에서 한국 공휴일 자동 연동 (캐시 지원) |
| **다크 모드** | 시스템 설정을 따르는 눈 편한 테마 |
| **모바일 우선** | 스마트폰과 태블릿에 최적화된 반응형 디자인 |
| **웹 푸시** | 태그, 요청, 업데이트에 대한 네이티브 브라우저 푸시 알림 |
| **PWA 지원** | iOS, Android 홈 화면에 설치 가능, 오프라인 지원 |
| **계정 대리 로그인** | 관리자가 피관리 계정으로 전환하여 조회/편집 |

---

## 기술 스택

- **백엔드:** Kotlin 2.3, Spring Boot 4.0 (Data JPA, Security, WebFlux, Scheduling, Caching, AI), Java 21
- **프론트엔드:** Vue 3.5 SPA (Vite 7 + TypeScript + Pinia + Tailwind CSS 4)
- **데이터베이스:** MySQL 8.0 + Flyway 마이그레이션 (47개 이상의 버전 관리)
- **AI:** Spring AI + Gemini (비동기 큐를 통한 일정 시간 파싱)
- **인증:** JWT Bearer 토큰 + 슬라이딩 리프레시 + 카카오 OAuth SSO
- **PWA:** VAPID 기반 웹 푸시 알림, iOS/Android 설치 가능
- **관측성:** Prometheus, Grafana, Slack 웹훅, 롤링 로그

---

## 빠른 시작

### 요구사항

- JDK 21+, Node.js 20+, Docker (권장)

### 개발 환경 설정

```bash
# 클론 및 설정
git clone https://github.com/ShanePark/dutypark.git
cd dutypark
cp .env.sample .env  # 플레이스홀더 채우기

# 데이터베이스 시작
cd dutypark_dev_db && docker compose up -d && cd ..

# 백엔드 시작 (터미널 1)
./gradlew bootRun

# 프론트엔드 시작 (터미널 2)
cd frontend && npm install && npm run dev
```

http://localhost:5173 을 열면 됩니다. Vite 개발 서버가 API 요청을 백엔드로 자동 프록시합니다.

### 프로덕션 배포

```bash
# 아티팩트 빌드
./gradlew build
cd frontend && npm run build && cd ..

# Docker Compose로 배포
docker compose up -d
```

전체 프로덕션 설정(TLS, Prometheus, Grafana)이 Compose 스택에 포함되어 있습니다.

---

## 아키텍처

```
┌─────────────────────────────────────────┐
│      Vue 3 SPA (frontend/)              │
│  Vite dev: http://localhost:5173        │
└────────────┬────────────────────────────┘
             │ /api/* proxy
             ▼
┌─────────────────────────────────────────┐
│   Spring Boot Backend (:8080)           │
│   REST API + JWT Auth                   │
└────────────┬────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│   MySQL 8.0 (:3306/3307)                │
└─────────────────────────────────────────┘
```

### 백엔드 모듈

| 모듈 | 역할 |
|:-----|:-----|
| `duty/` | 근무 CRUD, 엑셀 일괄 업로드 (`SungsimCakeParser`), 캘린더 집계 |
| `schedule/` | 일정, 태그, 검색, AI 파싱 큐/워커, 첨부파일 |
| `todo/` | 칸반 보드 (BACKLOG/TODO/DOING/DONE/CLOSED 상태) |
| `member/` | 친구, 가족, 디데이, 프로필, SSO 온보딩, 보조 계정 |
| `team/` | 팀, 관리자, 근무 유형, 공유 일정, 배치 템플릿 |
| `dashboard/` | "나 + 친구" 일일 집계 보기 (배치 로딩) |
| `notification/` | 이벤트 기반 비동기 처리 인앱 알림 (페이지네이션) |
| `push/` | VAPID 기반 웹 푸시 알림, iOS PWA 지원 |
| `attachment/` | 세션 기반 업로드, 썸네일, 야간 정리 스케줄러 |
| `holiday/` | 공공데이터포털 공휴일 (동시성 안전 캐싱) |
| `security/` | JWT, OAuth, 요청 제한, 권한, 관리자 필터링 |

### 프론트엔드 구조

```
frontend/src/
├── api/           # 13개 Axios 클라이언트 (duty, schedule, todo, team, member, notification, push 등)
├── components/    # 45개 이상 Vue SFC (FileUploader, Modals, KanbanBoard, Layout 등)
├── composables/   # 7개 훅 (useSwal, useKakao, usePushNotification, useEscapeKey 등)
├── stores/        # Pinia 스토어 (auth, notification 폴링, theme)
├── views/         # 19개 페이지 컴포넌트 (Dashboard, Duty, TodoBoard, Member, Team, Admin)
├── utils/         # 헬퍼 (color, date, visibility)
└── types/         # 50개 이상 TypeScript 인터페이스
```

---

## 설정

### 필수 환경 변수

| 변수 | 용도 |
|:-----|:-----|
| `JWT_SECRET` | 토큰 서명용 Base64 인코딩 시크릿 |
| `KAKAO_REST_API_KEY` | 카카오 OAuth 클라이언트 자격 증명 |
| `GEMINI_API_KEY` | 일정 파싱용 Google AI Studio 키 (선택) |
| `SLACK_TOKEN` | 운영 알림 봇 토큰 |
| `DATA_GO_KR_SERVICE_KEY` | 한국 공휴일 API 키 |
| `VAPID_PUBLIC_KEY` | 웹 푸시 공개 키 (`npx web-push generate-vapid-keys`로 생성) |
| `VAPID_PRIVATE_KEY` | 웹 푸시 비공개 키 |
| `ADMIN_EMAIL` | 관리자 이메일 주소 |

전체 목록은 `.env.sample`을 참조하세요 (DB 자격 증명, 도메인 설정, Docker 설정 포함).

---

## 기여하기

1. 저장소 포크
2. 기능 브랜치 생성 (`git checkout -b feature/amazing-feature`)
3. 변경사항 커밋 (`git commit -m 'Add amazing feature'`)
4. 브랜치에 푸시 (`git push origin feature/amazing-feature`)
5. Pull Request 열기

---

## 라이선스

[MIT License](LICENSE)에 따라 배포됩니다.

---

**Dutypark** — *당신의 일정은 단순한 근무 그 이상이니까요.*
