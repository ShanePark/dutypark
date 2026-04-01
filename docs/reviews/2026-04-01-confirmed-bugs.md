# 2026-04-01 Confirmed Bugs

검증 기준:
- 로컬 백엔드 `http://localhost:8080`
- 로컬 프론트 `http://localhost:5173`
- 테스트 계정 `test@duty.park / 12345678`
- 확인 시각: 2026-04-01 (Asia/Seoul)

## 1. Private 일정 기본정보가 인증 없이 노출됨

상태: 재현 완료, 수정 대상

영향:
- 일정 UUID를 알고 있으면 `visibility=PRIVATE` 일정의 `memberId`, `memberName`, `startDateTime`, `content`가 노출된다.
- 현재 구현은 소유자 캘린더 공개 여부만 보고 접근을 허용하며, 일정 자체의 visibility는 검사하지 않는다.

코드 근거:
- `src/main/kotlin/com/tistory/shanepark/dutypark/schedule/service/ScheduleService.kt:97`
- 비교 기준: `src/main/kotlin/com/tistory/shanepark/dutypark/schedule/service/SchedulePermissionService.kt:35`

재현 절차:
1. `POST /api/auth/token`으로 로그인한다.
2. `PUT /api/members/{내 ID}/visibility`에 `{"visibility":"PUBLIC"}`을 보낸다.
3. `POST /api/schedules`로 `visibility=PRIVATE`, `content=private-review-check` 일정 하나를 만든다.
4. 인증 쿠키 없이 `GET /api/schedules/{생성한 일정 UUID}`를 호출한다.

실제 결과:
- `200 OK`
- 응답 예시:

```json
{
  "id": "019d46c2-b990-7f94-4f4b-c0c1161a71c1",
  "memberId": 5,
  "memberName": "박세현",
  "startDateTime": "2026-04-10T00:00",
  "content": "private-review-check"
}
```

기대 결과:
- `401` 또는 `403`

정리:
- 재현 후 생성한 일정은 삭제했고, 계정 가시성도 다시 `FRIENDS`로 복구했다.

## 2. 잘못된 Bearer 헤더가 유효한 access token 쿠키 인증을 가로막음

상태: 재현 완료, 수정 대상

영향:
- 브라우저에 정상 `access_token` 쿠키가 있어도 잘못된 `Authorization` 헤더가 붙으면 로그인 상태가 사라진다.
- 구형 클라이언트, 프록시, 확장 프로그램이 잘못된 Bearer 헤더를 추가하는 경우 정상 세션이 깨질 수 있다.

코드 근거:
- `src/main/kotlin/com/tistory/shanepark/dutypark/security/filters/JwtAuthFilter.kt:34`

재현 절차:
1. `POST /api/auth/token`으로 로그인하고 쿠키를 확보한다.
2. 쿠키만 넣어 `GET /api/auth/status`를 호출한다.
3. 같은 쿠키에 `Authorization: Bearer garbage`를 추가해 `GET /api/auth/status`를 다시 호출한다.

실제 결과:
- 쿠키만 보냈을 때:

```json
{
  "id": 5,
  "email": "test@duty.park",
  "name": "박세현",
  "teamId": 4,
  "team": "관리팀",
  "isAdmin": true,
  "isImpersonating": false,
  "originalMemberId": null
}
```

- 잘못된 Bearer 헤더를 추가하면 빈 응답 본문으로 비로그인 처리됐다.

기대 결과:
- 잘못된 Bearer가 있더라도 유효한 쿠키 인증으로 fallback 하거나, 최소한 명시적으로 401을 반환해야 한다.
