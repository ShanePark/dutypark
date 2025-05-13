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

## 🛠️ 개발 환경

### 1. 요구 사항

- JDK 21 이상
- MySQL (또는 Docker 기반 DB)
- Gradle 8 이상

### 2. 데이터베이스 설정 (Docker)

```bash
cd dutypark_db
docker compose up -d
```

DB 계정 정보는 `src/main/resources/application-dev.yml`에 입력

### 3. 환경 설정

- 로컬 개발용 SSL 비활성화:

```yaml
server.ssl.enabled: false
server.port: 8080
```

- (선택) `application-*.yml`에 Slack 웹훅 및 공휴일 API 키 추가 가능

### 4. 빌드 및 실행

```bash
./gradlew build
java -jar build/libs/dutypark-0.0.1-SNAPSHOT.jar \
  --spring.profiles.active=prod
```

------

## 사용 예시

![eagles](README.assets/eagles.png)

손쉽게 일정을 관리해보세요
