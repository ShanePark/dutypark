# Dutypark iOS App Store 심사 전 점검 보고서

- 점검일: 2026-08-28 (KST)
- 후속 조치 완료일: 2026-08-29 (KST)
- 코드 점검 범위: `ios/` 디렉터리만
- 실기 QA 기기: `iPhone 13 mini` 시뮬레이터, iOS 26.5
- 빌드: Release, `1.0.0 (1)`, `io.github.shanepark.dutypark`
- 운영 API: `https://dutypark.o-r.kr/api/`
- 리뷰 계정: `app-review@dutypark.o-r.kr` (비밀번호는 보고서에 기록하지 않음)

## 1. 결론

**코드 리뷰에서 발견된 문제는 모두 조치 완료했다. 심사 제출 전에는 실기기/APNs와 서명 Archive만 최종 확인할 것을 권장한다.**

정적 리뷰에서 P0/P1 수준의 확정적인 인증 우회나 항상 재현되는 크래시는 발견되지 않았다. 후속 구현과 두 차례의 독립 diff 재리뷰를 거쳐 최종 결과는 `no findings`다. Release 빌드, 운영 API 연결, 리뷰 계정 로그인, 주요 탭 탐색과 Todo/D-Day 실제 CRUD도 성공했다.

최종 통합 검증은 focused 테스트 296건과 전체 `DutyparkTests` 1,126건을 실행했다. 전체 결과는 1,125 PASS, 1 SKIP, 0 FAIL이며, 스킵 1건은 시뮬레이터에서 파일 보호 동작을 재현할 수 없어 제외된 테스트다. 운영 Release 빌드와 `iPhone 13 mini` 설치·실행도 성공했다.

남은 항목은 코드상 확정 결함이 아니라 실제 기기·외부 시스템 또는 시스템 picker가 필요한 검증 공백이다.

1. 실제 iPhone에서 APNs 권한·토큰 등록·실제 알림 수신을 확인하지 않았다. 시뮬레이터에서는 이제 푸시 미지원 안내를 표시하고 토글의 사용자 선호와 등록 상태를 분리한다.
2. 캘린더 일정 CRUD, 실제 사진/파일 첨부 업로드, 소셜 OAuth는 시스템 UI 또는 외부 계정 제약 때문에 최종 E2E를 완료하지 못했다.
3. App Store 배포 인증서로 서명한 Archive와 App Store Connect 업로드는 수행하지 않았다.

### 제출 전 권장 게이트

- **필수:** 실제 iPhone에서 푸시 권한 허용/거부, 토글 변경, 앱 재실행 후 상태 유지, 실제 알림 수신을 확인한다.
- **필수:** 리뷰 계정으로 캘린더 일정의 생성·수정·삭제를 완료한다. D-Day CRUD는 확인 완료했다.
- **필수:** 사진/파일 첨부의 업로드·미리보기·다운로드·공유·삭제를 확인하고 로그아웃 뒤 로컬 임시파일 정리를 검증한다.
- **필수:** App Store 배포 서명 Archive의 운영 API와 APNs production entitlement를 확인한다.
- **권장:** 고해상도 사진, 10MB 근처 파일 여러 개, 큰 XLSX로 새 용량 제한과 오류 UX를 실제 기기에서 확인한다.

### 후속 조치 완료 내역

| 영역 | 조치 |
|---|---|
| 오프라인 친구 비교 | snapshot에 비교 멤버 ID를 저장하고 legacy/불일치 캐시의 비교 근무는 안전하게 제외; stale prefetch generation 차단 |
| 캘린더 접근성 | 날짜 셀 중복 접근성 요소를 제거하고 날짜별 고유 identifier 추가 |
| 일반 첨부 | FileRepresentation 수명 안에서 materialize, 파일 선검사·순차 처리·2048px 다운샘플 적용 |
| 첨부 임시파일 | 보호된 전용 store를 사용하고 QuickLook/공유/화면 이탈/로그아웃/계정 삭제에서 cleanup |
| 프로필 사진 | 입력 2048px/50MiB 검증, 출력 1024px/1MiB 제한, 메타데이터 확인 실패 보수적 거부 |
| Calendar/Team XLSX | 읽기 전 파일 크기 검사, multipart 전체 body 10MiB 미만 강제, repository 전송 경계 재검사, filename sanitization |
| Admin WebView | non-persistent website data store로 전환 |
| Todo 첨부 세션 | 계정+세션 generation 기반 durable discard queue, bounded retry, 로그아웃/cold launch 보존, 명시적 삭제에서만 purge |
| 푸시 설정 | 시뮬레이터 미지원과 실기기 실패 분리, 등록 상태와 사용자 선호 분리, 늦은 callback 방어 |

## 2. Release 빌드 및 설치 검증

실행 명령:

```sh
xcodebuild -project Dutypark.xcodeproj \
  -scheme Dutypark \
  -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 13 mini' \
  -derivedDataPath /tmp/dutypark-ios-review-dd \
  CODE_SIGNING_ALLOWED=NO build
```

결과:

- `BUILD SUCCEEDED`
- built `Info.plist`의 `DutyparkAPIBaseURL`: `https://dutypark.o-r.kr/api/`
- bundle identifier: `io.github.shanepark.dutypark`
- version/build: `1.0.0 (1)`
- 대상 시뮬레이터 UDID: `F0737016-7654-4967-83FA-1DFB951DB36E`
- Release 앱 설치·실행 성공
- QA 종료 시 앱은 리뷰 계정 로그인 상태로 남겨 둠

프로젝트 설정상 Debug 시뮬레이터는 `localhost:8080`, Release는 운영 API 및 APNs production을 사용한다. App Store Archive가 반드시 Release 설정을 사용하는지 Archive 직전 다시 확인해야 한다.

## 3. 리뷰 계정 실기 QA 결과

### PASS

| 영역 | 확인 내용 | 결과/비고 |
|---|---|---|
| 빌드/실행 | 운영 API 대상 Release 빌드, 설치, 실행 | PASS |
| 인증 | 리뷰 계정 로그인 | PASS |
| 기본 내비게이션 | Home, Calendar, Todo, Team, More 탭 진입 | PASS |
| 친구 | 친구 목록(7명), 무결과 검색, 도움말, 뒤로가기 | PASS |
| 알림 | 전체 읽음 처리, 읽은 알림 삭제 확인창 진입 후 취소 | PASS. 기존 알림 6건은 읽음 상태로 변경됨 |
| 이용안내 | 항목 펼침/접기 | PASS |
| 문의/지원 | 화면 진입, 탭 전환, 빈 상태 확인 | PASS. 실제 문의 제출은 하지 않음 |
| 설정 | 전체 스크롤, 테마/세션/소셜 연결 표시 확인 | PASS |
| 설정 | 다크 테마 전환 후 시스템 테마로 복원 | PASS |
| 내 정보 | 전체 스크롤 | PASS |
| 계정 삭제 | 삭제 1단계 화면 진입 후 취소 | PASS. 계정은 유지됨 |
| 세션 | 로그아웃 확인 모달, 로그아웃, 동일 계정 재로그인 | PASS |
| D-Day | `앱 리뷰 샘플 D-Day` 생성, 상세, 제목 수정, 삭제 | PASS. 샘플 잔존 없음 |
| 첨부 | Todo 사진 선택기 진입 | PASS. 시스템 picker 이후 실제 선택은 BLOCKED |
| Todo | `앱 리뷰 확인용 할 일`, `앱 리뷰 확인용 할 일 2` 생성 | PASS |
| Todo | 상세 진입, 제목에 `(수정)` 추가, 저장 | PASS |
| Todo | 완료 상태 컬럼 확인 및 삭제 | PASS |
| 샘플 정리 | QA에서 만든 Todo 제거 | PASS. 샘플 잔존 없음 |

Todo 자동화의 마지막 실행은 UI 동작이 끝까지 성공했으나 보조 XCUITest assertion 2건이 실패했다. `todo.detail`이 실제로는 `Button` 접근성 타입인데 테스트가 `otherElements`로 조회한 계측 오류다. 실행 로그에는 create/detail/edit/update/completed-state/drag/delete 단계와 delete PASS가 기록됐다. Drag 제스처는 수행했지만 서버의 최종 상태 이동은 별도로 확정하지 못했다.

### FAIL / 조건부 재검증

| 영역 | 관찰 결과 | 판단 |
|---|---|---|
| 푸시 설정 | 토글은 켜짐으로 보이지만 `알림 설정을 변경하지 못했습니다.` 오류 노출 | 시뮬레이터의 APNs 토큰/권한 제약일 수 있음. 실제 기기에서 반드시 재검증 |

Xcode 로그의 iOS 26.5 WebCore/WebKit accessibility duplicate 경고와 `DebuggerVersionStore` 경고는 이번 앱 기능 실패의 직접 근거가 아닌 실행 환경 경고로 분류했다.

### NOT RUN / BLOCKED

| 영역 | 미검증 내용 | 사유/위험 |
|---|---|---|
| 캘린더 | 일정 생성·수정·삭제 | 2026-08-28 날짜 셀이 접근성 트리에 6개 존재했지만 모두 `hittable=false`여서 작성 화면 진입 불가. 리뷰어 주요 경로이므로 제출 전 필수 |
| 캘린더 | 검색, 빠른 근무 입력, 일괄 입력 | 빠른 입력 identifier가 화면에 없었고 일정 진입도 실패. 실제 저장/원복 미수행 |
| 첨부파일 | 사진/파일 실제 선택, 업로드, 미리보기, 공유, 다운로드, 삭제 | 사진 picker 진입은 성공했으나 시스템 picker가 앱 UI 트리 밖이라 자동 취소/후속 file picker 제어 불가 |
| 팀 | 멤버·근무유형·팀 일정 변경, XLSX 업로드 | 타 사용자/팀 데이터에 영향을 줄 수 있어 변경하지 않음 |
| 친구/신고 | 친구 추가·삭제·차단·신고 | 타 계정에 영향을 줄 수 있어 변경하지 않음 |
| 문의 | 실제 문의 제출 | 리뷰 계정에 삭제 불가능한 데이터가 남을 수 있어 제출하지 않음 |
| 소셜 | OAuth 연결/해제 | 외부 계정 및 인증 흐름 미검증 |
| AI 일정 인식 | 동의 및 자동 인식 | 리뷰 계정 설정 화면의 접근성 요소에 토글이 노출되지 않아 진입 불가 |
| 푸시 | 실제 기기 권한 및 알림 수신 | 시뮬레이터로 확정 불가 |
| 오프라인 | 네트워크 차단 후 캐시 복원 | 호스트 네트워크에 영향을 주지 않는 안전한 시뮬레이터 전환 수단을 확보하지 못함 |

## 4. 정적 코드 리뷰 발견사항

아래 항목은 최초 점검에서 발견한 조치 전 문제를 기록한 것이다. 현재 구현에서는 모두 위의 후속 조치를 적용했고, 최종 독립 diff 재리뷰 결과는 `no findings`다.

### P2 — 오프라인 친구 비교 캐시가 선택 멤버를 식별하지 않음

- 근거: `Dutypark/Features/Calendar/CalendarViewModel.swift:519-527`, `:543-555`, `:600-633`; `Dutypark/Features/Calendar/OfflineModels.swift:313-327`
- 월별 snapshot의 키가 account ID와 월만 포함하고 비교 멤버 ID 집합을 보관하지 않는다. 오프라인 복원 시 현재 선택한 비교 대상과 대조하지 않고 `otherDuties`를 그대로 적용한다.
- 재현 후보: 온라인에서 친구 A 비교 캐시 생성 → 비교 대상을 B로 변경 → 오프라인 복원 시 B 화면에 A 근무가 표시될 수 있다.
- 권고: snapshot에 `comparedMemberIDs`를 저장해 일치할 때만 적용하거나, 멤버 집합을 캐시 키에 포함한다. 불일치하면 비교 근무를 비워 안전하게 표시한다.

### P2 — 여러 첨부 사진/동영상을 전체 메모리로 적재

- 근거: `Dutypark/Features/Attachments/AttachmentFileLoader.swift:8-18`, `:58-86`; `Dutypark/Features/Attachments/AttachmentPicker.swift:242-255`, `:448-455`
- `PhotosPickerItem`을 `Data` 전체로 읽은 뒤 10MB 제한을 검사한다. 최대 10개를 배열에 누적하고 HEIC 변환 중 원본 Data, `UIImage`, JPEG Data가 동시에 존재할 수 있다.
- 위험: iPhone 13 mini에서 메모리 압박, 앱 종료, 심한 지연.
- 권고: file-backed representation으로 크기를 먼저 검사하고 순차 변환/업로드, 이미지 다운샘플링, 전체 선택 용량 제한을 적용한다.

### P2 — 프로필 사진 업로드의 픽셀·바이트 상한 부재

- 근거: `Dutypark/Features/Settings/MyInfoView.swift:670-680`; `Dutypark/Features/Settings/ProfilePhotoCropView.swift:115-136`; `Dutypark/Features/Settings/SettingsService.swift:181-195`
- 고해상도 이미지를 원본 해상도로 디코드·정규화·crop·JPEG 변환하고 multipart body에 다시 복제한다.
- 권고: ImageIO thumbnail/downsample, crop 결과 최대 변 길이와 바이트 상한, 업로드 전 명시적 용량 오류를 추가한다.

### P2 — 비공개 첨부 임시파일이 세션 경계에서 삭제되지 않음

- 근거: `Dutypark/Features/Attachments/AttachmentGallery.swift:169-179`, `:280`, `:286-289`, `:462-479`; `Dutypark/Core/Offline/OfflineLocalDataPurger.swift:20-44`
- 비공개 첨부를 `temporaryDirectory/DutyparkAttachments/`에 저장하지만 Quick Look/Share 완료, 로그아웃, 계정 삭제 시 명시적 정리가 없다.
- 위험: OS가 임시 디렉터리를 정리하기 전까지 이전 사용자의 비공개 콘텐츠가 앱 컨테이너에 남는다.
- 권고: TTL과 완료/취소 cleanup을 적용하고 logout/account deletion purge에 포함한다.

### P2 — 팀 XLSX 업로드가 크기 선검사 없이 파일을 중복 적재

- 근거: `Dutypark/Features/Team/TeamManageView.swift:1372-1384`; `Dutypark/Features/Team/TeamViewModel.swift:728-741`; `Dutypark/Features/Team/TeamFeatureModels.swift:130-146`
- 확장자만 검사한 뒤 파일 전체를 `Data(contentsOf:)`로 읽고 multipart body에 다시 복제한다.
- 권고: URL resource values로 파일 크기를 먼저 제한하고 file-backed/streaming multipart와 현지화된 용량 오류를 사용한다.

### P3 — 팀 XLSX 파일명을 multipart header에 raw 삽입

- 근거: `Dutypark/Features/Team/TeamFeatureModels.swift:139-145`; `Dutypark/Features/Team/TeamViewModel.swift:737`
- 사용자가 선택한 filename의 quote, backslash, CR/LF를 escape하지 않아 특수한 파일명에서 multipart header가 깨질 수 있다.
- 권고: `Dutypark/Features/Attachments/MultipartFormData.swift:60-74`의 escape 정책을 재사용하는 공통 multipart builder로 통합한다.

### P2 조건부 — Admin WKWebView cookie store가 세션 경계에서 정리되지 않음

- 근거: `Dutypark/Features/Admin/AdminWebView.swift:156-182`; `Dutypark/Core/Networking/APIClient.swift:485-494`
- `WKWebsiteDataStore.default()`에 쿠키를 복사하지만 로컬 인증 제거는 shared cookie만 지우고 WKWebView store를 지우지 않는다.
- 위험 조건: 서버가 모든 계정 전환에서 동일 쿠키를 확실히 overwrite/invalidate하지 않거나 WebView가 재사용되면 이전 관리자 세션이 남을 수 있다.
- 권고: 세션별 non-persistent store 또는 logout/account switch 시 해당 origin의 website data와 `WKHTTPCookieStore`를 명시 삭제하고 WebView를 재생성한다.

### P2 조건부 — Todo 화면 해제 시 첨부 세션 discard가 fire-and-forget

- 근거: `Dutypark/Features/Todo/TodoView.swift:1720-1725`, `:1931-1949`
- 정상 취소 경로와 달리 `onDisappear`에서는 discard 완료를 기다리거나 실패를 재시도하지 않는다.
- 위험 조건: 네트워크 장애, 로그아웃, 앱 종료와 화면 해제가 겹치면 서버 임시 attachment session이 남을 수 있다.
- 권고: 서버 TTL/cleanup을 보장하고 session ID를 retry outbox에 보존하거나, dismissal 전에 discard 완료를 기다리며 실패 상태를 유지한다.

## 5. App Store 심사 관점 체크

### 확인된 긍정 요소

- Release API는 HTTPS이며 ATS arbitrary loads 설정은 확인되지 않았다.
- `PrivacyInfo.xcprivacy`와 카메라 사용 설명 리소스가 존재한다.
- 리뷰 계정으로 주요 화면과 실제 Todo CRUD에 접근할 수 있다.
- 계정 삭제 진입점이 존재하며 취소 흐름이 동작한다.
- 정적 리뷰에서 P0/P1 수준의 확정적 인증 우회나 항상 재현되는 크래시는 찾지 못했다.

### 심사 메모에 포함할 내용

- 리뷰 계정 ID와 비밀번호는 App Store Connect의 보안 필드에만 입력한다.
- 주요 기능 진입 경로를 간단히 적는다. 특히 팀/캘린더/첨부 기능에 사전 데이터나 권한이 필요하면 명시한다.
- 외부 OAuth 없이도 핵심 기능을 확인할 수 있는지 명시한다. OAuth가 필수라면 해당 테스트 절차와 계정을 별도로 제공한다.
- 푸시 기능이 심사의 핵심이라면 실제 기기에서 검증 완료 후 필요한 조건을 심사 메모에 설명한다.

## 6. 데이터 변경 및 정리 상태

- 생성한 Todo 샘플 2건은 모두 삭제했다.
- 생성한 D-Day 샘플은 수정 검증 후 삭제했다.
- 리뷰 계정의 기존 알림 6건을 전체 읽음 처리했다. 이는 운영 계정에 남은 유일하게 확인된 상태 변경이다.
- 친구, 팀, 다른 사용자, 계정 자체는 변경하지 않았다.
- 캘린더 일정과 문의 데이터는 생성하지 않았다.
- 테마는 다크로 변경한 뒤 시스템 설정으로 복원했다.
- 시뮬레이터의 앱은 리뷰 계정 로그인 상태다.

## 7. 검증 방식과 한계

- macOS Assistive Access 제한 때문에 좌표 기반 GUI 자동화 대신 임시 XCUITest, 접근성 트리, 스크린샷, 실행 로그를 사용했다.
- QA용 테스트와 증거는 `/tmp`에만 생성했으며 저장소에 남기지 않았다.
- 정적 리뷰와 실기 QA는 별도 서브에이전트가 수행했다.
- 정적 리뷰 에이전트는 빌드/단위 테스트를 별도로 실행하지 않았다.
- 실기 QA는 App Store의 실제 심사 기기와 동일하지 않은 시뮬레이터 결과다. APNs, 카메라, Photos/File picker, OAuth 등은 실기기 검증을 대체하지 않는다.
- 저장소의 기존 문서에 기록된 과거 검증 결과는 이번 실행 결과로 간주하지 않았다.
- 후속 수정 최종 검증: 전체 `DutyparkTests` 1,125 PASS / 1 SKIP / 0 FAIL, Release `BUILD SUCCEEDED`, 운영 endpoint 확인, `iPhone 13 mini` 설치·실행 성공.

## 8. 최종 제출 체크리스트

- [ ] 실제 iPhone에서 푸시 설정 오류가 재현되지 않고 알림 수신까지 성공한다.
- [ ] 캘린더 일정 CRUD를 리뷰 계정으로 완료한다.
- [x] D-Day CRUD를 리뷰 계정으로 완료한다.
- [ ] 사진 및 파일 첨부의 업로드·미리보기·공유·삭제를 완료한다.
- [x] 로그아웃 후 리뷰 계정 재로그인을 완료한다.
- [x] 오프라인 비교 캐시에 멤버 ID 검증과 stale prefetch 차단을 적용하고 회귀 테스트를 통과한다.
- [x] private attachment 임시파일 cleanup과 non-persistent Admin WebView session 회귀 테스트를 통과한다.
- [ ] 고해상도 사진·복수 첨부·큰 XLSX 입력에서 앱이 종료되지 않고 명확한 용량 오류를 보여준다.
- [ ] App Store Connect 심사 메모에 리뷰 계정과 주요 기능 진입 경로를 기재한다.
- [ ] Archive가 Release 운영 API/APNs production 설정을 사용하는지 최종 산출물에서 다시 확인한다.
