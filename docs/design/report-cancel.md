# 내 신고 취소 (Report withdrawal)

## 결정 사항

| 항목 | 결정 |
| --- | --- |
| 취소 처리 방식 | `ReportStatus.CANCELED` 상태로 철회. 레코드는 증거로 보존하고 관리자 대기열에서 제외 |
| 취소 가능 조건 | 신고자 본인의 `OPEN` 신고만 |
| 차단 연동 | 없음. 신고 취소는 차단 상태를 건드리지 않는다 |
| 재신고 | 취소 후 같은 대상 재신고 시 새 신고가 생성된다 (중복 병합은 `OPEN`만 대상) |

## API 계약 (단일 소유자: 백엔드)

```
POST /api/reports/{reportId}/cancel
```

- 인증: 로그인 필수. 미로그인 → 401 `auth.unauthorized`
- 200 OK → body: `MyReportDto` (status=`CANCELED`, resolvedAt=취소 시각)
- 404 `common.notFound` → 존재하지 않거나 내가 신고한 건이 아님 (타인 신고의 존재 여부를 노출하지 않음)
- 400 `report.cancel.notOpen` → 이미 처리(RESOLVED/DISMISSED)되었거나 이미 취소된 건

`ReportStatus`에 `CANCELED` 추가. `status` 컬럼은 VARCHAR(20)에 체크 제약이 없으므로 Flyway 마이그레이션 불필요.

## 작업 분할 (병렬)

- **WP1 백엔드** — `src/main/**`, `src/test/**`
- **WP2 웹** — `frontend/**`
- **WP3 iOS** — `ios/**`

파일 겹침 없음. 세 WP 모두 위 API 계약을 고정 전제로 진행한다.
