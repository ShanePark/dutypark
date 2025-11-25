# Dutypark SPA 전환 - Phase 4 (수렴/정리)

> Phase 0-3 완료. 38개 기능 100% SPA 구현 완료. Thymeleaf 완전 제거됨.

---

## 완료된 작업

- [x] 전환된 경로의 Thymeleaf 뷰 제거 (27개 템플릿)
- [x] Thymeleaf ViewController 제거 (6개 컨트롤러)
- [x] Thymeleaf 의존성 제거 (build.gradle.kts)
- [x] 레거시 CSS/JS/lib 제거

## 남은 작업

- [ ] SPA 정적 서빙 및 `/api/**` 네임스페이스 분리 (nginx 설정)
- [ ] 문서/런북 업데이트

---

## SPA 정적 서빙 (nginx)

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

---

## 문서 업데이트

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
