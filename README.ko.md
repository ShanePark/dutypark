# Dutypark

[한국어](README.ko.md) | [English](README.md)

[https://dutypark.o-r.kr](https://dutypark.o-r.kr)

<a href="#" target="_blank"><img src="https://img.shields.io/badge/Kotlin-7F52FF?style=flat-square&logo=Kotlin&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/Spring Boot-6DB33F?style=flat-square&logo=Spring-Boot&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/JPA-ED2761?style=flat-square&logo=Spring&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/MySQL-4479A1?style=flat-square&logo=MySQL&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/Vue.js-4FC08D?style=flat-square&logo=Vue.js&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/TypeScript-3178C6?style=flat-square&logo=TypeScript&logoColor=white"/></a>

> **근무와 일정을 빠르게 추가하고 친구나 가족과 공유하세요.**

근무 명단, 개인 일정, 할 일, 디데이 카운터를 위한 경량 Kotlin + Spring Boot 웹 애플리케이션입니다. Dutypark은 Vue 기반 캘린더 UI, AI 지원 일정 파싱, 미디어 첨부 파일, 팀 협업 기능을 결합하여 개발자와 일반 사용자 모두 모든 디바이스에서 교대 근무, 이벤트, 알림을 조율할 수 있습니다.

---

## 🚀 주요 기능

| 카테고리 | 기능 | 설명 |
|:---------------------------|:------------------------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **근무 관리** | 근무 캘린더 | 기본 휴무 타입 대체 및 빠른 월별 탐색을 위한 캐시된 캘린더 그리드가 포함된 색상 구분 근무/휴무일. |
|  | 엑셀 스케줄 가져오기 | `SungsimCake` 파서를 통한 멤버 또는 전체 팀의 교대 근무 일괄 업로드; 이름 자동 매핑, 누락된 멤버 자동 생성, 선택한 월을 안전하게 덮어쓰기. |
| **일정 및 첨부파일** | 이벤트 일정 관리 | 공개 설정, 태그 지정 가능한 참가자, 일별 드래그 정렬, 첨부 파일 인식 CRUD API가 포함된 풍부한 일정 편집기. |
|  | 디데이 카운트다운 | 개인 + 공유 디데이 이벤트, 공개 설정 토글, SweetAlert 편집기, 캘린더에서 빠른 참조를 위한 로컬 스토리지 선택. |
|  | LLM 시간 파싱 큐 | Spring AI + Gemini를 통해 자연어 제목에서 시작/종료 시간을 추출하고 속도 제한 워커 및 자동 상태 추적(WAIT → PARSED/FAILED). |
|  | 일정 첨부파일 | Uppy 기반 세션 기반 업로드, 재개 가능한 진행 UI, 썸네일 생성(Thumbnailator + TwelveMonkeys), 엄격한 권한 검사. |
|  | 일정 검색 모달 | 페이지네이션 및 근무 캘린더 내 날짜 이동 기능이 있는 일정 전체 텍스트 검색. |
| **할 일 및 대시보드** | 할 일 보드 및 개요 | Vue + SortableJS 보드를 통한 드래그 순서 조정, 모달 편집, 다시 열기/완료 액션, 개요 필터, 인라인 토스트. |
|  | 대시보드 개요 | 나 + 친구를 위한 일일 스냅샷: 근무, 일정, 고정 순서, 친구/가족 토글, 대기 중인 요청 관리. |
| **공유 및 협업** | 친구 및 가족 공유 | `Visibility` 열거형을 통한 가시성 인식 캘린더 공유 및 추가 권한을 제공하는 가족 태그 지정. |
|  | 일정 태그 지정 | 친구/가족에게 태그를 지정하여 알림을 보내고 대시보드/일별 그리드에서 공유 일정을 자동으로 표시. |
|  | 다중 계정 관리 | 리프레시 토큰/자동 로그인 쿠키를 활용한 계정 전환 또는 관리로 원활한 로그인. |
| **팀 및 조직** | 팀 캘린더 | 모든 멤버의 명단과 집계된 팀 일정, 빈 슬롯에 대한 기본 근무 색상을 표시하는 팀 보기. |
|  | 팀 관리자 컨트롤 | 관리자는 멤버 초대/제거, Pickr를 통한 근무 유형/색상 구성, 작업 유형 + 근무 일괄 템플릿 관리 가능. |
|  | 팀 일정 및 템플릿 | 전용 팀 일정 보드(`TeamScheduleService`) 및 작업 유형, 근무 기본값, 엑셀 일괄 처리를 위한 재사용 가능한 템플릿. |
| **통합 및 자동화** | 공휴일 동기화 | Data.go.kr (공공데이터포털) 통합, 캐싱, DB 지속성, 중복 가져오기를 방지하는 동시성 잠금. |
|  | Slack 운영 훅 | 시작/종료 업데이트 및 예외 요약이 `SlackNotifier` 및 `@SlackNotification` aspect를 통해 Slack으로 전송. |
| **모니터링 및 운영** | Prometheus + Grafana | Micrometer 메트릭이 `/actuator/prometheus`에 노출되고, 번들 Prometheus 구성으로 스크랩되며 Grafana를 통해 시각화(기본 `admin/admin`). |
| **보안** | OAuth 로그인 | 가입/동의 화면 및 `MemberSsoRegister` 유효성 검사가 포함된 카카오 SSO 플로우. |
|  | JWT + 리프레시 쿠키 | HttpOnly 세션 쿠키 + 슬라이딩 리프레시 토큰, 관리자 필터링, HTTPS 배포를 위한 쿠키 보안 토글. |

---

## 🧱 기술 스택

- **백엔드:** Kotlin 2.1.10, Spring Boot 3.5.6 (Data JPA, Web, WebFlux, Validation, Security, Actuator, DevTools), Java 21 툴체인.
- **데이터:** MySQL 8.0 + Flyway 마이그레이션(`db/migration/v1`, `v2`), JPA 감사, ULID 엔티티, 선택적 P6Spy SQL 추적.
- **AI 및 메시징:** Spring AI 스타터(OpenAI 호환 엔드포인트를 통한 Gemini 2.0 Flash Lite) 및 Slack 웹훅 통합.
- **프론트엔드:** Vue 3 SPA (Vite + TypeScript + Pinia + Tailwind CSS), 백엔드와 완전 분리된 JWT Bearer 토큰 인증.
- **빌드 및 문서화:** Gradle Kotlin DSL, `org.asciidoctor.jvm.convert` 및 git-properties 플러그인(Slack + `/actuator/info`에 표시).
- **관찰 가능성 및 운영:** Micrometer Prometheus 레지스트리, Grafana 대시보드, Logback 롤링 파일, Docker Compose 오케스트레이션.
- **테스팅:** JUnit 5, H2 인메모리 DB, Mockito-Kotlin, fail-fast Gradle 테스트 실행.

---

## 🗂 아키텍처 하이라이트

### 백엔드 모듈
- `duty/` — 근무 CRUD 및 템플릿 유효성 검사, 이름 중복 제거, 팀 멤버 일괄 업데이트를 수행하는 엑셀 일괄 수집(`DutyBatchSungsimService`).
- `schedule/` — 태그 지정, 캘린더 집계, 검색 서비스, 첨부 파일 오케스트레이션이 포함된 일정 서비스; AI 시간 파싱 큐 포함.
- `todo/` — UUID 기반 할 일 엔티티, 순서 조정 가능한 위치, 다시 열기/완료 플로우, 개요 쿼리.
- `attachment/` — 업로드 세션, 유효성 검사, 이미지 썸네일 생성(비동기 실행기), 정리 스케줄러, 파일시스템 추상화.
- `member/` — 친구/가족 관계, 디데이 관리, 공개 설정 적용, 리프레시 토큰, SSO 온보딩.
- `team/` — 팀 CRUD, 관리자 역할, 근무 유형 구성, 작업 유형 프리셋, 공유 팀 일정.
- `dashboard/` — 근무, 일정, 친구 요청 데이터로 구성된 "나 + 친구" 집계 보기.
- `holiday/` — `WebClientAdapter` + 캐싱, 잠금, DB 지속성/재설정 API로 구축된 DataGoKr 클라이언트.
- `security/` — JWT 제공자, 쿠키, 카카오 OAuth, `@Login` 인수 리졸버, 관리자 필터, 전달 헤더 지원.
- `common/` — 레이아웃 헬퍼, 캐시된 `/api/calendar` 그리드, Slack 알림 인프라, 비동기/스로틀 구성, 사용자 정의 로깅 구성.

### 프론트엔드 레이어
- Vue 3 SPA, Composition API (`<script setup lang="ts">`) 및 TypeScript로 타입 안전성 확보.
- Pinia를 통한 상태 관리 (JWT 토큰 처리 포함 인증 스토어).
- Vue Router의 지연 로딩 라우트 및 인증용 네비게이션 가드.
- Axios 요청/응답 인터셉터를 통한 자동 JWT 갱신.
- Tailwind CSS 기반 스타일링 및 커스텀 디자인 토큰.
- SortableJS 드래그 드롭 정렬, Uppy 파일 업로드, SweetAlert2 알림.

### 통합 및 자동화
- Spring Scheduling은 첨부 파일 세션 정리(오전 2시) 및 AI 파싱 큐를 지원; 캘린더/공휴일에 대한 캐싱 활성화.
- Slack notifier는 시작/종료/이벤트 및 선택적 `@SlackNotification` aspect 메시지를 전송.
- `DataGoKrConfig`는 사용자 정의 시간 초과를 사용하여 탄력적인 API 호출을 위해 WebFlux를 사용.
- 첨부 파일 썸네일은 업로드 요청을 빠르게 유지하기 위해 전용 비동기 실행기에서 실행.

---

## 🧑‍💻 로컬 개발

### 요구사항
- JDK 21+
- Docker & Docker Compose (선택사항이지만 전체 스택/로컬 DB에 권장)
- MySQL 클라이언트(선택사항) 직접 DB 액세스용

### 클론 및 구성
```bash
git clone https://github.com/ShanePark/dutypark.git
cd dutypark
cp .env.sample .env   # 스택 실행 전 플레이스홀더 채우기
```

### Gradle로 실행
```bash
./gradlew bootRun          # Spring Boot 앱 시작 (application-dev.yml을 통해 DevTools 활성화)
./gradlew test             # H2에서 fail-fast 단위/통합 테스트 실행
./gradlew build            # 컴파일 + 테스트 실행
./gradlew asciidoctor      # Spring REST Docs를 src/main/resources/static/docs로 생성
```

### Docker Compose로 실행
```bash
# HTTP 전용 로컬 스택 (data/nginx.local.conf 사용 및 TLS 건너뛰기)
NGINX_CONF_NAME=nginx.local.conf docker compose up -d

# 프로덕션 스타일 스택 (HTTPS + nginx 리버스 프록시)
docker compose up -d
```
Compose 파일은 MySQL, Spring Boot 앱, nginx(HTTP→HTTPS 리디렉션 + HSTS), Prometheus, Grafana를 시작합니다. 앱 로그 및 첨부 파일 저장소는 `./data/` 아래에 바인드 마운트됩니다.

### 개발 전용 데이터베이스
Gradle을 통해 앱을 실행하는 동안 MySQL만 필요하신가요? 헬퍼 스택을 사용하세요:

```bash
cd dutypark_dev_db
docker compose up -d   # localhost:3307에 MySQL 노출
```

`application-dev.yml`(이미 구성됨) 또는 `.env`를 `jdbc:mysql://localhost:3307/dutypark`로 지정하세요.

### 프로덕션 배포 체크리스트
1. 도메인 + TLS 인증서(Let's Encrypt) 프로비저닝.
2. 프로덕션 시크릿(DB, JWT, OAuth, Slack, Gemini 등)으로 `.env` 업데이트.
3. `docker compose up -d` 실행(기본값은 HTTPS를 가정하는 `data/nginx.conf`).
4. Prometheus/Grafana를 통해 `/actuator/health` 및 `/actuator/prometheus` 모니터링.
5. 시크릿 및 SSL 인증서를 주기적으로 갱신.

### 모니터링(선택사항)
Prometheus 및 Grafana 서비스는 기본 Compose 스택의 일부입니다. Grafana는 `http://localhost:3000`에서 수신 대기하며 자격 증명은 `admin/admin`이고, 데이터 디렉터리는 `./data/grafana`에 유지됩니다. Prometheus는 `data/prometheus/prometheus.yml`에 정의된 대로 `app:8080/actuator/prometheus`를 스크랩합니다.

---

## ⚙️ 구성

### 환경 변수(`.env`)
| 키 | 목적 |
|:------------------|:----------------------------------------------------------------------------|
| `MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD` | Compose DB 컨테이너용 MySQL root/user 자격 증명. |
| `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` | Compose 외부에서 배포할 때 JDBC 연결 재정의. |
| `JWT_SECRET` | 액세스 토큰 서명을 위한 Base64 인코딩 시크릿(`jwt.secret`). |
| `ADMIN_EMAIL` | `dutypark.adminEmails`에 삽입된 쉼표로 구분된 관리자 이메일. |
| `SLACK_TOKEN` | 운영 알림용 Slack 봇 토큰. |
| `DATA_GO_KR_SERVICE_KEY` | 공휴일 API 키(디코딩됨). |
| `KAKAO_REST_API_KEY` | 카카오 OAuth 클라이언트 자격 증명. |
| `GEMINI_API_KEY` | Spring AI에서 사용하는 Google AI Studio(Gemini) 키. |
| `DOMAIN_NAME` | nginx 템플릿 + SSL 볼륨에서 사용. |
| `COOKIE_SSL_ENABLED` | 쿠키의 Secure 플래그 토글(`dutypark.ssl.enabled`). |
| `NGINX_CONF_NAME` | `nginx.conf`(TLS) 또는 `nginx.local.conf`(HTTP) 선택. |
| `TZ` | 컨테이너 타임존(기본값 Asia/Seoul). |
| `UID`, `GID` | 마운트된 볼륨의 파일 소유권(로그, Grafana, 저장소). |

### 애플리케이션 설정
`src/main/resources/application.yml`은 가장 중요한 설정을 노출합니다:

```yaml
spring:
  ai.openai:
    api-key: "${GEMINI_API_KEY:EMPTY}"
    chat:
      base-url: https://generativelanguage.googleapis.com/v1beta/openai/
      options:
        model: gemini-2.0-flash-lite
        temperature: 0.0
dutypark:
  storage:
    root: /dutypark/storage
    max-file-size: 50MB
    thumbnail:
      max-side: 200
    session-expiration-hours: 24
  slack.token: "${SLACK_TOKEN: }"
  data-go-kr.service-key: "${DATA_GO_KR_SERVICE_KEY:DECODED_SERVICE_KEY_HERE}"
jwt:
  secret: "${JWT_SECRET:...}"
management.endpoints.web.exposure.include: health,metrics,prometheus
```

`application-dev.yml`은 DB 자격 증명(포트 3307)을 재정의하고, DevTools를 활성화하며, SSL을 비활성화하고, 로컬 디렉터리에 로그를 기록하며, 안전한 로컬 테스트를 위해 Slack/API 키를 스텁합니다.

---

## 📁 디렉터리 가이드

| 경로 | 목적 |
|:--------------------------------------------|:----------------------------------------------------------------------------------------------|
| `src/main/kotlin/com/tistory/shanepark/dutypark/duty` | 근무 엔티티, 컨트롤러, 서비스, 엑셀 일괄 가져오기 로직. |
| `src/main/kotlin/com/tistory/shanepark/dutypark/schedule` | 일정 CRUD, 태그 지정, 검색, 첨부 파일 훅, AI 파싱 큐. |
| `src/main/kotlin/com/tistory/shanepark/dutypark/todo` | 할 일 컨트롤러/서비스/엔티티 DTO. |
| `src/main/kotlin/com/tistory/shanepark/dutypark/attachment` | 업로드 세션, 유효성 검사, 파일시스템 헬퍼, 썸네일 서비스, 정리 스케줄러. |
| `src/main/kotlin/com/tistory/shanepark/dutypark/member` | 친구 관계, 디데이 API, 리프레시 토큰, SSO 플로우, `@Login` 어노테이션. |
| `src/main/kotlin/com/tistory/shanepark/dutypark/team` | 팀/도메인 로직(관리자, 일정, 작업 유형, 근무 유형). |
| `src/main/kotlin/com/tistory/shanepark/dutypark/security` | JWT 인증, 필터, 카카오 OAuth, 관리자 라우팅, 쿠키 구성. |
| `src/main/kotlin/com/tistory/shanepark/dutypark/dashboard` | 근무 + 일정을 집계하는 대시보드 컨트롤러/서비스. |
| `frontend/` | Vue 3 SPA 소스 코드 (Vite + TypeScript + Pinia + Tailwind CSS). |
| `src/main/resources/db/migration` | 스키마를 정의/업그레이드하는 Flyway SQL 스크립트(`v1`, `v2`). |
| `src/docs/asciidoc` | Spring REST Docs용 소스; 빌드 출력은 `static/docs`로 복사. |
| `data/` | Docker 볼륨: MySQL 데이터, 로그, nginx 템플릿, Prometheus, Grafana, 저장소. |
| `dutypark_dev_db/` | 로컬 개발을 위한 독립형 MySQL docker-compose 스택. |
| `README.assets/` | 문서에서 참조하는 이미지(예: 스크린샷). |

---

## 🗂 첨부파일 및 저장소

- 업로드는 `AttachmentContextType`(`SCHEDULE`, `PROFILE`, `TEAM`, `TODO`)을 대상으로 하며 임시 업로드 세션(`AttachmentUploadSessionService`) 내부에서 시작.
- Vue 상세 모달은 Uppy를 동적으로 초기화하고, 필요에 따라 세션을 생성하며, 크기 제한(`dutypark.storage.max-file-size`)을 적용하고, ETA + 속도 추정치로 실시간 진행 상황을 추적.
- `AttachmentService`는 메타데이터를 유지하고, `AttachmentPermissionEvaluator`를 통해 소유권을 적용하며, `AttachmentUploadedEvent` + `ThumbnailService`를 통해 썸네일을 트리거.
- 썸네일은 Thumbnailator + TwelveMonkeys 코덱(JPEG/WebP 지원)을 사용하여 `thumbnailExecutor`(`AsyncConfig`)에서 비동기적으로 생성.
- `AttachmentCleanupScheduler`는 매일 02:00에 실행되어 만료된 세션/파일을 삭제하고 고아 업로드를 디스크에서 제거.
- 모든 파일시스템 경로는 `StoragePathResolver`를 통해 확인되므로 `dutypark.storage.root`를 변경하여 저장소를 재배치 가능.

---

## 🧠 AI 지원 일정 관리

- `ScheduleTimeParsingQueueManager`는 `ParsingTimeStatus.WAIT`로 일정을 모니터링하고, 대기열에 추가하며, Gemini 제한(30 RPM, 1500 RPD)을 적용.
- 각 작업은 원본 DB 트랜잭션이 커밋되도록 10초 지연된 후 `ScheduleTimeParsingWorker`가 이미 명시적 시간이 있거나 시간 관련 텍스트가 없는 항목을 건너뜀.
- `ScheduleTimeParsingService`는 JSON 전용 프롬프트를 작성하고, 코드 펜스를 제거하고, 응답을 `ScheduleTimeParsingResponse`로 역직렬화.
- 워커 결과는 `ParsingTimeStatus`(`PARSED`, `FAILED`, `NO_TIME_INFO`, `ALREADY_HAVE_TIME_INFO`)를 업데이트하고 시작/종료 시간 + `contentWithoutTime`을 유지.
- `GEMINI_API_KEY`를 설정(또는 `spring.ai.openai.*` 재정의)하여 큐를 활성화; 비워두면 일정 생성을 손상시키지 않고 AI 파싱을 자동으로 비활성화.

---

## 🔒 보안 및 액세스 제어

- `JwtAuthFilter`는 HttpOnly 세션 쿠키를 읽고, 슬라이딩 리프레시 토큰(`RefreshTokenService`)을 통해 만료된 토큰을 갱신하며, `@Login`으로 주석이 달린 컨트롤러에 `LoginMember` 속성을 주입.
- `AuthService`는 자동 로그인 쿠키를 발급하고, 비밀번호 변경 시 리프레시 토큰을 취소하며, 쿠키 보안을 토글할 때 `dutypark.ssl.enabled`를 준수.
- 카카오 OAuth(`security/oauth/kakao`)는 토큰 교환 + 사용자 정보를 처리하고, `/member/sso` 페이지는 약관 동의로 온보딩을 완료.
- `DutyparkProperties.adminEmails`는 상승된 액세스를 관리하고, `AdminAuthFilter`는 `/admin/**` + `/docs/**`를 제한.
- 첨부 파일 API는 세션 소유권 + 컨텍스트 수준 권한을 적용; 일정/할 일/팀 컨트롤러는 가시성 확인을 위해 `FriendService` 및 `SchedulePermissionService`에 위임.
- 가시성 열거형(`PUBLIC`, `FRIENDS`, `FAMILY`, `PRIVATE`) 및 친구/가족 관계는 누가 일정/근무를 읽을 수 있는지 결정.
- `ForwardedHeaderFilter` + nginx 헤더는 배포를 리버스 프록시 친화적으로 만듭니다.

---

## 📊 모니터링 및 운영

- Spring Actuator는 `/actuator/health`, `/actuator/info`, `/actuator/prometheus`를 노출(`management.endpoints.web.exposure.include`를 통해 활성화).
- Prometheus 구성(`data/prometheus/prometheus.yml`)은 자체 및 앱을 모두 스크랩; Grafana 대시보드는 `data/grafana` 아래에 유지.
- Slack 알림: `ApplicationStartupShutdownListener`는 라이프사이클 알림(`git.properties`에서 브랜치 + 커밋 포함)을 게시하고, `ErrorDetectAdvisor`는 요청 메타데이터와 함께 예외 페이로드를 전송.
- Logback은 `dutypark.log.path`에 롤링 일일 로그를 기록(기본값 `/dutypark/logs`, 지속성을 위해 Docker를 통해 마운트).
- Micrometer + Prometheus 레지스트리는 JVM/앱 메트릭을 캡처; P6Spy는 `decorator.datasource.p6spy.enable-logging`을 통해 토글 가능.
- `spy.log`(P6Spy 출력) 및 `data/logs`는 SQL 및 앱 동작 문제 해결에 도움.

---

## 🎨 프론트엔드 경험

- Vue 3 SPA, TypeScript와 Composition API로 타입 안전하고 유지보수 가능한 코드.
- Tailwind CSS 기반 반응형 디자인, 모바일 디바이스 최적화.
- SweetAlert 팝업과 localStorage를 활용한 디데이 관리.
- SortableJS 드래그 드롭 정렬과 인라인 토스트를 활용한 할 일 보드.
- Uppy를 통한 실시간 진행률 표시줄과 썸네일 미리보기가 포함된 일정 상세 모달.
- Axios 인터셉터를 통한 자동 갱신 처리가 포함된 JWT Bearer 토큰 인증.

---

## 🐳 Docker 및 배포

- `docker-compose.yml`은 5개의 서비스를 정의: `mysql`, `app`, `nginx`, `prometheus`, `grafana`. 앱 로그 + 첨부 파일 저장소는 `./data/logs` 및 `./data/storage`에 바인드 마운트.
- nginx 템플릿은 `data/nginx.conf`(HTTPS) 및 `data/nginx.local.conf`(HTTP)에 있음. `NGINX_CONF_NAME`을 통해 선택.
- TLS 인증서는 호스트의 `/etc/letsencrypt/...` 아래에 있을 것으로 예상되며, nginx 컨테이너에 읽기 전용으로 마운트.
- `/actuator/**` 경로는 nginx 구성 내에서 IP 제한(루프백 + Docker 네트워크 허용).
- `dutypark_dev_db/docker-compose.yml`은 포트 3307에서 MySQL만 실행하기 위한 트리밍된 스택.
- `UID/GID` 환경 변수는 Linux 호스트에서 마운트된 볼륨이 쓰기 가능하도록 보장.
- Prometheus + Grafana 데이터 디렉터리는 각각 `./data/prometheus` 및 `./data/grafana` 아래에 유지.

---

## 📄 API 문서 및 테스팅

- `./gradlew test`는 `failFast = true`로 실행되며, H2 + Mockito-Kotlin을 사용하여 스위트가 빠르게 완료.
- `./gradlew asciidoctor`는 테스트에 의존한 다음 생성된 REST Docs를 `src/main/resources/static/docs`로 복사(AdminAuthFilter로 보호되는 `/docs` 아래에서 제공).
- 빌드 파이프라인은 일반 `jar` 작업을 비활성화하고(Spring Boot fat jar만 해당) `build` → `asciidoctor`를 연결.
- `./gradlew test --tests "SomeTestClass"`를 사용하여 특정 스위트를 대상으로 지정; 릴리스 빌드의 경우 `./gradlew clean build`.

---

## 🖼 사용 예시

![eagles](./README.assets/eagles.png)

**dutypark**으로 즐겁게 계획하세요.

---

## 📄 라이센스

[MIT License](LICENSE)에 따라 배포됩니다.
