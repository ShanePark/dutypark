# 13. 모바일 웹 → iOS UI/UX 동등성 마감 보고

- 기준일: 2026-08-16
- 기준 화면: 반응형 모바일 웹과 iPhone 13 mini(`375×812pt`)
- 상태 기준: `해결됨`은 구현, 자동 검증, 필요한 실제 입력 또는 시각 검증까지 끝난 항목이다.
- 범위: 이번 대화에서 요청받은 iOS UI/UX, 새로고침, 드래그, 내비게이션, 정책 문서, 관리자 화면

## 최종 요약

| 구분 | 상태 |
| --- | --- |
| 요청받은 제품 이슈 | **24개 모두 해결됨** |
| Generic iOS Simulator `build-for-testing` | **성공** |
| 전체 `DutyparkTests` | **531/531 통과, 실패 0, skip 0** |
| 동적 파라미터 포함 실행 | **545회 통과** |
| iPhone 13 mini 집중 UI 검증 | **요청 이슈별 통과** |
| 실물 iPhone 설치 | **완료 — Shane iPhone, Release 개발 서명** |
| TestFlight 배포 | **대기 — 본인 기기 확인에는 직접 설치로 충분** |

현재 소스에서 재현되는 것으로 확인된 요청 이슈는 남아 있지 않다. 배포와 App Store 심사는 제품 UX 수정과 별도 릴리스 절차로 관리한다.

## 요청 이슈별 상태

| # | 영역 | 요청·증상 | 상태 | 해결 내용 | 대표 커밋 |
| --- | --- | --- | --- | --- | --- |
| 1 | 전역 | mutation 뒤 불필요한 전체 새로고침과 화면 깜빡임 | 해결됨 | Home·Social·Todo·Calendar·Team·Settings·알림·관리자를 로컬 반영 또는 silent refresh로 전환 | `c08cbb1c`, `8de613ab`, `1419cd1d`, `a5fb9279`, `157056ec`, `f1d6cb8f`, `279c9e3b` |
| 2 | Home 친구 | 친구 카드 위에서 세로 스크롤 불가 | 해결됨 | ScrollView와 공존하는 long-press recognizer 및 drag 취소 가능한 카드 탭 적용 | `a5fb9279` |
| 3 | Home 친구 | 즐겨찾기 등록 직후 화면이 크게 아래로 이동 | 해결됨 | 로컬 pin 상태 반영, 콘텐츠 유지, silent reconcile로 교체 | `a5fb9279` |
| 4 | Home 친구 | 즐겨찾기 해제 불가 | 해결됨 | 별 버튼과 카드 drag/tap 제스처를 분리 | `a5fb9279` |
| 5 | Home 친구 | 친구 카드를 눌러도 해당 친구 시간표로 이동하지 않음 | 해결됨 | 별 버튼과 카드 내비게이션 hit target 분리, 고정·일반 카드 모두 검증 | `a5fb9279` |
| 6 | Home 친구 | 상단 네 친구는 드래그 재정렬되지 않고 다섯 번째부터만 동작 | 해결됨 | LazyVStack의 화면 밖 frame까지 요구하던 조건 제거 | `c50b6c0b` |
| 7 | 친구관리 | 고정 친구 drag & drop 전체 불가 | 해결됨 | 스크롤 호환 long-press 재정렬과 optimistic 저장 적용 | `ec6a1c3d` |
| 8 | 친구관리 | 카드가 팀·오늘 근무·일정까지 표시해 웹보다 과밀 | 해결됨 | 프로필·이름·가족·별·더보기 중심의 모바일 웹 밀도로 정리 | `d186bbf9` |
| 9 | 내 달력 Todo | `+`가 전체 Todo 화면을 열어 빠른 추가를 방해 | 해결됨 | `TodoCreateModal`을 열고 기본 상태를 `진행중`으로 유지하는 실제 탭 회귀 테스트 추가 | `157056ec`, `533ea4cf` |
| 10 | 내 달력 Todo | 표시된 Todo를 누르면 전체 Todo 목록이 열림 | 해결됨 | 상단·달력 셀 Todo 모두 선택한 항목의 상세 모달로 직접 연결 | `533ea4cf` |
| 11 | 내 달력 Todo | Todo 추가 옆에 전체 Todo 관리 진입이 중복 노출 | 해결됨 | Calendar의 전체 관리 route/button 제거, `+`와 하단 Todo dock만 유지 | `533ea4cf` |
| 12 | 내 달력 | 상단 월 내비게이션이 화면 중앙에서 벗어남 | 해결됨 | 좌우 동일 폭 레이아웃으로 월 이동 컨트롤의 실제 중앙 정렬 보장 | `533ea4cf` |
| 13 | 내 달력 | 근무 함께 보기에서 프로필 사진 표현이 웹과 다름 | 해결됨 | 사진 metadata와 avatar/fallback을 비교 근무 행에 적용 | `533ea4cf` |
| 14 | Todo | 카드 drag 시 대상 카드가 아니라 컬럼 전체가 움직임 | 해결됨 | drag 중 가로 board scroll 잠금, drop 전 live projection 제거 | `b5a6452c` |
| 15 | Team | 일정 추가 모달을 열었다 닫으면 앱 크래시 | 해결됨 | optional Binding 강제 해제를 제거하고 editor가 non-optional draft를 소유 | `8de613ab` |
| 16 | 전역 내비게이션 | 화면 왼쪽 edge swipe 뒤로 가기가 사라짐 | 해결됨 | push 깊이를 인식하는 interactive-pop bridge를 TeamManage와 Login 흐름에 적용 | `a696c950` |
| 17 | 알림 전체보기 | 상단에 붙어 있어 다시 내리거나 닫기 어려움 | 해결됨 | large sheet drag indicator, 44pt 상단 닫기, swipe-down dismiss 제공 | `e1a42278` |
| 18 | 햄버거 메뉴 | dock과 중복되는 Home·달력·Todo·Team·설정 항목 | 해결됨 | 메뉴를 친구관리·알림·이용 안내·로그아웃 중심으로 단순화, admin만 관리자 추가 | `e1a42278` |
| 19 | 정책 문서 | AI 시간 인식 정책·약관·개인정보의 줄바꿈과 가독성이 나쁨 | 해결됨 | heading·문단·목록·표를 블록별 렌더링, 표 card reflow, Dynamic Type·선택·접근성 적용 | `68859d2a` |
| 20 | 관리자 | 회원·팀·개발·API 화면과 정보 위계가 웹과 크게 다름 | 해결됨 | 4개 진입점, 검색/empty, avatar, 상세 상태·날짜, 팀 목록·생성 route, embedded locale/theme 정합화 | `8be144e0`, `02ca15d2` |
| 21 | 관리자 팀 | 팀 생성·삭제 뒤 목록 전체 재조회와 spinner | 해결됨 | 생성·삭제 결과를 현재 페이지에 로컬 반영 | `279c9e3b` |
| 22 | 관리자 팀 | 모든 팀 row에 위험한 swipe 삭제가 노출됨 | 해결됨 | 목록 swipe 제거, 서비스 관리자이면서 멤버 0명인 팀의 관리 header에만 삭제 제공 | `dc740481`, `66880e47` |
| 23 | 설정 세션 | 개별 접속 세션 종료가 모두 `로그아웃`으로 축약 | 해결됨 | 제목 `접속 세션 종료`, 실행 `접속 종료`로 웹 문구와 일치 | `59808d19` |
| 24 | 공개/관리 콘텐츠 경계 | 네이티브 정책 콘텐츠와 관리자 개발 WebView 계약 충돌 | 해결됨 | 공개 콘텐츠는 네이티브, WebView는 인증된 관리자 개발 도구 한 파일만 허용 | `e590e9a4` |

## 핵심 검증

### 통합

- Generic iOS Simulator `build-for-testing`: 성공
- 전체 `DutyparkTests`: 531/531 통과, 실패 0, skip 0
- 동적 파라미터 포함: 545회 통과
- 결과: `/tmp/Dutypark-Integration-Unit-Rerun-20260816.xcresult`
- 콘텐츠 경계: 3/3 통과, `/tmp/Dutypark-NativeContentBoundary-Focused-20260816.xcresult`

### 실제 입력·시각 검증

| 기능 | 결과 | 증빙 |
| --- | --- | --- |
| Home 카드 스크롤·pin/unpin·친구 시간표 | 3/3 통과 | `/tmp/Dutypark-HomeFriendInteractions-UI-DPLongPress-Final-20260815.xcresult` |
| Home 상단 고정 친구 4개 재정렬 시나리오 | 4개 시나리오 통과 | `/tmp/dutypark-home-reorder-green/Logs/Test/Test-Dutypark-2026.08.15_22-44-38-+0900.xcresult` |
| 친구관리 재정렬·스크롤·시간표 | 3/3 통과 | `/tmp/Dutypark-SocialPinnedReorder-GREEN-20260815-Actual.xcresult` |
| 친구관리 compact 카드 | unit 1/1, UI 1/1 | `/tmp/Dutypark-SocialDensity-GREEN-20260816.xcresult` |
| Calendar 상세·중앙 월 nav·비교 avatar | unit 47/47, UI 1/1 | `/tmp/Dutypark-CalendarParity-UI-20260815-2315.xcresult` |
| Calendar Todo 빠른 추가 | UI 1/1 | `/tmp/Dutypark-CalendarQuickAdd-UI-20260815.xcresult` |
| Todo 카드 단독 drag | UI 1/1 | `/tmp/Dutypark-TodoCardOnlyDrag-GREEN3-20260815.xcresult` |
| Team 일정 modal open→cancel | UI 1/1 | `/tmp/Dutypark-TeamModal-UI-GREEN-2.xcresult` |
| 왼쪽 edge swipe 뒤로 가기 | UI 2/2 | `/tmp/Dutypark-InteractivePop-UI-Retry-20260815.xcresult` |
| 알림 close·swipe-down·메뉴 exact | 모두 통과 | `/tmp/Dutypark-NotificationCenter-Close-Green-20260815.xcresult` |
| 장문 정책 Dynamic Type | unit 7/7, UI 2/2 | `/tmp/Dutypark-LongForm-DirectRoute-Final-20260816.xcresult` |
| 관리자 landing·회원 상세 | UI 1/1 | `/tmp/Dutypark-Admin-LandingDetail-Final-20260816.xcresult` |
| 관리자 empty-team 삭제 정책 | unit 64 logical, populated UI 1/1 | `/tmp/Dutypark-TeamDelete-Unit-Full.xcresult`, `/tmp/Dutypark-TeamDelete-UI-GREEN.xcresult` |
| 설정 세션 exact 문구 | Settings 35/35 | `/tmp/Dutypark-SettingsSessionCopy-GREEN2.xcresult` |

## 이번 마감 커밋

| 커밋 | 내용 |
| --- | --- |
| `c50b6c0b` | Home 상단 고정 친구 재정렬 복구 |
| `ec6a1c3d` | 친구관리 재정렬 복구 |
| `533ea4cf` | Calendar Todo·월 header·비교 avatar 정합화 |
| `b5a6452c` | Todo 카드 drag 시 컬럼 고정 |
| `e1a42278` | Root 메뉴 단순화와 알림 dismiss 개선 |
| `8be144e0` | 관리자 화면 모바일 웹 정합화 |
| `a696c950` | edge swipe와 근무유형 확인 흐름 복구 |
| `68859d2a` | 장문 정책 문서 가독성 개선 |
| `02ca15d2` | 관리자 navigation·접근성 안정화 |
| `d186bbf9` | 친구관리 카드 밀도 단순화 |
| `59808d19` | 개별 접속 세션 종료 문구 명확화 |
| `dc740481` | 관리자 팀 삭제를 빈 팀 상세로 제한 |
| `66880e47` | populated 팀 삭제 미노출 UI 회귀 테스트 |
| `e590e9a4` | 네이티브 콘텐츠·관리자 WebView 경계 고정 |

## 남은 할 일

### 제품 이슈

- 현재 요청 범위에서 확인된 미해결 제품 이슈 없음.

### 릴리스 절차

- 실물 iPhone에 최신 Release 빌드 직접 설치: **완료**
  - 기기: `Shane iPhone` / iPhone 13 mini
  - Bundle ID: `io.github.shanepark.dutypark`
  - 빌드: `/tmp/Dutypark-PhysicalInstall-20260816/Build/Products/Release-iphoneos/Dutypark.app`
  - 자동 실행은 기기가 잠겨 있어 iOS가 거부했다. 잠금 해제 후 설치된 Dutypark 아이콘을 열어 최초 실행을 확인한다.
- TestFlight archive/업로드/내부 테스터 배포: **대기**
- App Store Connect Validate App 및 심사 제출: **대기**

직접 설치는 개발 서명으로 본인 iPhone에서 즉시 확인할 때 사용한다. TestFlight는 다른 테스터 배포, 설치 유지, 배포 이력 관리가 필요할 때 진행한다.
