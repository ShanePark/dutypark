# Dutypark

[https://dutypark.o-r.kr](https://dutypark.o-r.kr/)

<a href="#" target="_blank"><img src="https://img.shields.io/badge/Kotlin-7F52FF?style=flat-square&logo=Kotlin&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/Spring Boot-6DB33F?style=flat-square&logo=Spring-Boot&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/JPA-ED2761?style=flat-square&logo=Spring&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/MySQL-4479A1?style=flat-square&logo=MySQL&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/Thymeleaf-005F0F?style=flat-square&logo=Thymeleaf&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/Vue.js-4FC08D?style=flat-square&logo=Vue.js&logoColor=white"/></a>

> **근무와 일정을 손쉽게 관리하고, 친구,가족과 공유하세요.**

**Dutypark**는 가볍고 직관적인 웹 기반 일정/근무 관리 서비스에요. 개발자가 아니어도 누구나 쉽게 사용할 수 있으며, 근무일정, 개인 일정, D-Day 카운트, TODO 리스트 까지 관리하고 공유할 수 있어요.

------

## 🚀 주요 기능

| 카테고리            | 기능명               | 설명                                                         |
| ------------------- | -------------------- | ------------------------------------------------------------ |
| **근무 관리**       | 근무 캘린더          | 색상으로 구분된 근무/휴무일 표시                             |
|                     | 엑셀 업로드          | 시간표 엑셀 파일을 통한 모든 팀원들의 근무 일정 일괄 등록    |
| **일정 관리**       | 일정 등록            | 전체 공개 / 친구 / 가족 / 비공개 설정 가능                   |
|                     | D-Day 카운트         | D-n 형식의 일정 표시                                         |
|                     | LLM 기반 자연어 파싱 | 이벤트 제목에서 날짜/시간 자동 추출                          |
| **공유 및 협업**    | 친구 및 가족 공유    | 캘린더 공유 및 세부 권한 설정                                |
|                     | 일정 태깅            | 친구/가족 태그로 알림 및 자동 포함                           |
|                     | 멀티 계정 관리       | 여러 계정 간 손쉬운 전환 및 관리                             |
| **팀/조직 기능**    | 팀 캘린더            | 팀/가족 단위 그룹 일정 공유                                  |
|                     | 팀 관리자 기능       | 팀원 추가/삭제, 근무 유형 커스터마이징 기능                  |
| **외부 연동**       | 공휴일 자동 등록     | 공공 API (data.go.kr)로 임시공휴일도 포함하여 공휴일 자동 등록. |
|                     | 소셜 로그인          | 카카오 로그인 기본 제공 (기타 제공자 확장 가능)              |
| **UI 및 앱 사용성** | 모바일/PWA 지원      | 반응형 디자인 및 앱 설치 가능 (Progressive Web App 지원)     |

------

## 🛠️ 빠른 시작

### 사전 요구사항
- Docker & Docker Compose
- (선택사항) 운영환경용 도메인 및 SSL 인증서

### 개발 환경 설정

1. **프로젝트 클론 및 설정**
   ```bash
   git clone https://github.com/ShanePark/dutypark.git
   cd dutypark
   cp .env.sample .env
   ```

2. **환경변수 편집**
   ```bash
   # .env 파일을 설정에 맞게 편집
   MYSQL_ROOT_PASSWORD=안전한_패스워드
   MYSQL_PASSWORD=데이터베이스_패스워드
   JWT_SECRET=base64_인코딩된_JWT_시크릿
   # ... 필요에 따라 다른 변수들도 설정
   ```

3. **Docker Compose로 실행**
   ```bash
   # 로컬 개발용 (HTTP만 사용)
   NGINX_CONF_NAME=nginx.local.conf docker compose up -d
   
   # 운영환경용 (HTTPS, SSL 사용)
   docker compose up -d
   ```

4. **애플리케이션 접속**
   - 로컬: http://localhost
   - 운영: https://your-domain.com

### 개발용 데이터베이스만 사용
앱은 로컬에서 실행하고 데이터베이스만 Docker를 사용하려면:
```bash
cd dutypark_dev_db
docker compose up -d  # MySQL이 3307 포트에서 실행됨
```

### 운영 배포
1. Let's Encrypt로 SSL 인증서 설정
2. `.env`를 운영환경 값으로 설정
3. `docker compose up -d` 실행

### 모니터링 (선택사항)
- **Prometheus**: 내부 메트릭 수집
- **Grafana**: http://localhost:3000 에서 접속 가능 (admin/admin)

------

## 사용 예시

![eagles](README.assets/eagles.png)

손쉽게 일정을 관리해보세요
