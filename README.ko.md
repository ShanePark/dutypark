<p align="center">
  <a href="https://apps.apple.com/kr/app/dutypark/id6801560782">
    <img src="frontend/public/apple-touch-icon.png" width="120" alt="Dutypark 앱 아이콘">
  </a>
</p>

# Dutypark

**한국어** | [English](README.md)

> 근무와 일정, 소중한 사람들을 위한 소셜 캘린더

Dutypark은 근무표와 일상의 약속을 하나의 캘린더에서 관리하고, 친구·가족·팀과 필요한 일정만 나눌 수 있는 서비스입니다.

[웹](https://dutypark.o-r.kr/) · [App Store](https://apps.apple.com/kr/app/dutypark/id6801560782)

## 주요 기능

- 근무와 일정을 색상별 월간 캘린더로 관리
- 일정마다 전체·친구·가족·비공개 범위를 선택하고 친구를 태그
- 팀 근무표를 함께 확인하고 지원되는 엑셀 근무표를 일괄 등록
- 할 일, 디데이, 검색, 알림으로 일상을 정리
- 네이티브 iPhone 앱에서 캐시된 캘린더와 할 일 데이터를 오프라인으로 확인

더 자세한 서비스 소개는 [Dutypark 홈페이지](https://dutypark.o-r.kr/)와 App Store에서 확인할 수 있습니다.

## 저장소 구성

- `src/` — Kotlin·Spring Boot 백엔드
- `frontend/` — Vue 3·TypeScript·Vite 웹 앱
- `ios/` — SwiftUI 기반 네이티브 iPhone 앱
- `docs/` — 데모, 디자인, App Store 에셋 작업 문서

데이터베이스는 MySQL과 Flyway 마이그레이션을 사용합니다. 플랫폼별 상세 내용은 [`frontend/README.md`](frontend/README.md), [`ios/README.md`](ios/README.md), [`docs/app-store/README.md`](docs/app-store/README.md)를 참고하세요.

## 로컬 개발

JDK 25+, Node.js 20+, Docker가 필요합니다. iOS 개발에는 Xcode 26+가 추가로 필요합니다.

```bash
# 터미널 1
cd dutypark_dev_db
docker compose up -d

# 터미널 2 (저장소 루트에서)
./gradlew bootRun --args='--spring.profiles.active=dev'

# 터미널 3 (저장소 루트에서)
cd frontend
npm install
npm run dev
```

웹 앱은 [http://localhost:5173](http://localhost:5173)에서 실행되며, API 요청을 `http://localhost:8080`의 백엔드로 프록시합니다.

## 라이선스

[MIT](LICENSE)
