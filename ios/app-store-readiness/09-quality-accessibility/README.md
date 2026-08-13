# 품질, 호환성 및 접근성 검증 가이드

최종 확인일: 2026-08-13

이 문서는 Dutypark iOS 앱의 지원 범위를 명확히 하고 App Review 전 수동·자동 품질 검증을 반복 가능하게 만드는 체크리스트다.
테스트에는 가짜 계정과 테스트 데이터만 사용하며 비밀번호, 토큰, 실제 개인정보를 문서나 저장소에 남기지 않는다.

## 관련 문서와 코드

- 빌드·테스트 명령과 지원 버전: [iOS README](../../README.md)
- 전체 출시 선행 조건: [iOS 배포 체크리스트](../../DEPLOYMENT_CHECKLIST.md)
- iPhone·세로 방향 설정: [Xcode 프로젝트 설정](../../Dutypark.xcodeproj/project.pbxproj)
- 접근성 토큰과 44pt 기준: [DPDesignTokens.swift](../../Dutypark/Components/DPDesignTokens.swift)
- 캘린더 날짜 셀: [CalendarView.swift](../../Dutypark/Features/Calendar/CalendarView.swift)
- Todo 드래그·대체 동작: [TodoView.swift](../../Dutypark/Features/Todo/TodoView.swift)
- 현재 자동 UI 테스트: [DutyparkUITests.swift](../../DutyparkUITests/DutyparkUITests.swift)
- 현지화 카탈로그 회귀 테스트: [LocalizationCatalogTests.swift](../../DutyparkTests/LocalizationCatalogTests.swift)
- 현지화 선택 로직: [AppLocalization.swift](../../Dutypark/Core/Localization/AppLocalization.swift)

## 1. 공식 지원 범위

- [x] 프로젝트 대상은 iPhone 전용(`TARGETED_DEVICE_FAMILY = 1`)이다.
- [x] iPhone 지원 방향은 세로(`UIInterfaceOrientationPortrait`)로 제한되어 있다.
- [x] 최소 지원 버전은 iOS 17이다.
- [x] unsigned generic iOS Release Archive의 `UIDeviceFamily = [1]`, 최소 iOS `17.0`, iPhone 세로 방향 설정이 프로젝트와 일치한다.
- [ ] App Store 설명과 지원 문서가 iPhone 전용·세로 방향 범위와 일치한다.
- [ ] iPad 호환 실행을 의도하지 않았다면 App Store Connect 노출을 확인한다.
- [ ] 화면 회전 잠금과 멀티태스킹 환경에서도 레이아웃이 깨지지 않는지 확인한다.
- [ ] 키보드 표시 시 입력 필드와 저장·취소 버튼이 가려지지 않는지 확인한다.

Apple의 인터페이스 접근성 원칙은 [Accessibility](https://developer.apple.com/accessibility/)와
[Human Interface Guidelines: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)를 기준으로 한다.

## 2. 필수 기기 매트릭스

- [ ] iPhone 13 mini(375×812)에서 전체 핵심 흐름을 확인한다.
- [ ] iPhone 16 Pro(402×874)에서 전체 핵심 흐름을 확인한다.
- [ ] 최소 한 대 이상의 실제 iPhone에서 TestFlight 빌드를 확인한다.
- [ ] 작은 화면에서 탭 바, 툴바, sheet의 최종 버튼이 잘리지 않는다.
- [ ] 긴 제목, 긴 이름, 많은 일정과 Todo가 있어도 가로 overflow가 없다.
- [ ] Safe Area, 홈 인디케이터, Dynamic Island 주변 콘텐츠가 겹치지 않는다.
- [ ] 스크롤 가능한 화면에서 마지막 항목과 버튼까지 도달할 수 있다.
- [ ] 사진·파일 선택과 공유 sheet를 시뮬레이터가 아닌 실기기에서도 검증한다.

## 3. 언어·테마·글자 크기 매트릭스

지원 언어는 한국어와 영어 2개다.
모든 조합을 완전 탐색하기 어려우면 핵심 화면은 전 조합, 나머지 화면은 pairwise 방식으로 기록한다.

- [x] `ko` × Light × 기본/최대 Dynamic Type 자동 핵심 내비게이션·scale evidence
- [x] `ko` × Dark × 기본/최대 Dynamic Type 자동 핵심 내비게이션·scale evidence
- [x] `en` × Light × 기본/최대 Dynamic Type 자동 핵심 내비게이션·scale evidence
- [x] `en` × Dark × 기본/최대 Dynamic Type 자동 핵심 내비게이션·scale evidence
- [x] `Dutypark/Resources`의 String Catalog 8개에서 한국어·영어 번역, 중복, placeholder와 런타임 Bundle lookup을 자동 검증한다.
- [ ] 모든 사용자 노출 문자열이 번역되고 키 이름이 그대로 보이지 않는다.
- [ ] 긴 영어 문자열이 버튼, 탭, 경고창에서 잘리지 않는다.
- [ ] Dark Mode에서 텍스트, 경계선, disabled 상태와 오류 메시지가 구분된다.
- [ ] 최대 Dynamic Type에서 확대, 줄바꿈 또는 스크롤로 기능을 끝까지 수행할 수 있다.
- [ ] 고정 높이 때문에 텍스트가 잘리는 화면을 기록하고 수정한다.

Dynamic Type 검증 기준은 [Apple의 글자 크기 지원 안내](https://developer.apple.com/documentation/uikit/scaling-fonts-automatically)를 참고한다.

위 체크는 iPhone 16 Pro와 iPhone 13 mini(iOS 26.5)에서 홈·설정 탭의 고정 accessibility ID,
현지화 label, hittable과 44×44pt 이상 터치 영역, 설정 진입·홈 복귀, theme accessibility value를
자동 검증한 범위다. 최대 글자 크기에서 전체 화면의 clipping, 모든 기능 완주와 수동 시각 품질을
확인했다는 의미는 아니며 아래 수동 항목은 남겨 둔다.

## 4. VoiceOver와 의미 구조

- [ ] 로그인부터 로그아웃까지 VoiceOver만으로 이동할 수 있다.
- [ ] 탭, 제목, 버튼, 입력 필드의 읽기 순서가 시각적 순서와 일치한다.
- [ ] 아이콘 전용 버튼에 기능을 설명하는 현지화된 label과 필요한 hint가 있다.
- [ ] 선택 상태, 읽지 않음, 로딩, 오류와 비활성 상태가 음성으로 전달된다.
- [ ] sheet와 modal을 열면 포커스가 내부로 이동하고 닫으면 호출 지점으로 돌아온다.
- [ ] 접근성 Escape로 닫을 수 있는 modal이 일관되게 동작한다.
- [ ] 삭제·로그아웃·회원 탈퇴 같은 위험 동작은 결과가 명확히 읽힌다.
- [ ] 장식 이미지와 중복 텍스트는 접근성 트리에서 숨긴다.

### 캘린더 날짜 셀 집중 점검

현재 [CalendarView.swift](../../Dutypark/Features/Calendar/CalendarView.swift)의 날짜 셀은 날짜 문자열 중심의 label을 제공한다.
VoiceOver 사용자가 셀을 보지 않고도 의미를 이해하고 동작할 수 있도록 다음을 검증한다.

- [ ] 날짜, 요일, 오늘 여부, 현재 월 포함 여부가 자연스러운 언어로 읽힌다.
- [ ] 근무, 휴일, 일정, Todo, D-day 개수와 핵심 내용이 과도하지 않게 요약된다.
- [ ] 선택된 날짜는 `.isSelected` 등 상태로 구분된다.
- [ ] 날짜 열기, 일정 추가, Todo 추가 등 가능한 동작이 action 또는 hint로 전달된다.
- [ ] 한 셀에 콘텐츠가 많아도 읽기 순서와 이동 단위가 예측 가능하다.
- [ ] 월 이동 후 VoiceOver 포커스가 사라지거나 엉뚱한 날짜로 이동하지 않는다.
- [ ] 빈 날짜, 다른 달 날짜, 오늘, 휴일, 여러 일정이 있는 날짜를 각각 확인한다.

VoiceOver 수동 검증은 [Apple VoiceOver 테스트 안내](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/test-with-assistive-technologies/)를 참고한다.

## 5. 44pt 터치 영역

- [ ] 모든 주요 버튼과 아이콘 전용 버튼의 실제 hit target이 최소 44×44pt다.
- [ ] 탭 바, 알림 벨, 추가, 닫기, 뒤로가기, 더보기 버튼을 우선 측정한다.
- [ ] 시각적 아이콘이 작더라도 padding과 `contentShape`가 전체 영역에 적용된다.
- [ ] 인접 버튼의 터치 영역이 겹치거나 잘못된 동작을 실행하지 않는다.
- [ ] 최대 Dynamic Type에서도 터치 영역이 축소되지 않는다.
- [x] 기본·최대 Dynamic Type에서 홈·설정 탭이 hittable이며 각각 44×44pt 이상으로 측정된다.
- [x] [DutyparkUITests.swift](../../DutyparkUITests/DutyparkUITests.swift)의 탭 대기 조건을 공통화해 터치 영역 테스트를 안정화한다.
- [x] iPhone 16 Pro(iOS 26.5) 대상 실행에서 `todo.add` 요소가 XCUI에 발견되고 44pt 이상으로 측정된다.

44pt 권장 기준은 [Human Interface Guidelines: Layout](https://developer.apple.com/design/human-interface-guidelines/layout)을 따른다.

## 6. Todo 드래그의 대체 조작

[TodoView.swift](../../Dutypark/Features/Todo/TodoView.swift)는 카드에 위로 이동, 아래로 이동과 다른 상태로 이동하는 접근성 action을 제공한다.
드래그를 사용할 수 없는 사용자에게 기능적으로 동등한 경로인지 아래 항목으로 검증한다.

- [ ] VoiceOver rotor/actions에서 위로 이동과 아래로 이동을 발견할 수 있다.
- [ ] 각 다른 Todo 상태로 이동하는 action 이름이 현재 언어로 읽힌다.
- [ ] 첫 카드의 위로 이동과 마지막 카드의 아래로 이동이 잘못 실행되지 않는다.
- [ ] 이동 성공 후 새 위치와 상태가 음성 또는 화면 상태로 확인된다.
- [ ] 네트워크 실패 시 원래 위치로 복구되고 오류가 읽힌다.
- [ ] Switch Control과 키보드 탐색에서도 드래그 없이 순서를 변경할 수 있다.
- [ ] 필요한 경우 상세 화면이나 context menu에 명시적인 이동 UI를 추가한다.
- [ ] 드래그와 대체 조작이 동일한 권한 검사·API를 사용한다.

## 7. 네트워크와 장애 시나리오

- [ ] 앱 첫 실행 중 오프라인에서도 게스트 화면 또는 복구 동작에 도달한다.
- [ ] 느린 네트워크에서 중복 저장과 중복 제출이 발생하지 않는다.
- [ ] 연결 중단 후 재시도하면 일정·Todo CRUD가 중복 생성되지 않는다.
- [ ] 401에서 세션 갱신 또는 로그아웃 전환이 무한 반복되지 않는다.
- [ ] 403은 권한 부족으로, 404는 삭제·미존재 상태로 이해 가능하게 표시된다.
- [ ] 429는 사용자가 기다리거나 재시도할 수 있는 메시지를 제공한다.
- [ ] 5xx에서 앱이 종료되지 않고 사용자 작업 내용이 가능한 한 보존된다.
- [ ] 이미지·첨부 업로드 중 오프라인 전환과 취소를 확인한다.
- [ ] APNs 권한 거부, 토큰 등록 실패와 서버 해제 실패가 앱 사용을 막지 않는다.
- [ ] 백그라운드 복귀 시 오래된 화면 데이터가 안전하게 갱신된다.
- [ ] 오류 alert가 자동 UI 테스트의 버튼이나 화면 식별자를 가리지 않도록 mock 상태를 통제한다.

네트워크 검증은 Network Link Conditioner, 프록시 또는 제어 가능한 테스트 서버 응답을 사용하되 운영 장애를 유발하지 않는다.

## 8. UI 자동화 안정화

- [x] 각 UI 테스트는 언어, 테마와 인증 상태를 명시적으로 초기화한다.
- [x] 각 UI 테스트에 필요한 테스트 데이터를 명시적으로 초기화한다.
- [x] 고정 sleep 대신 `waitForExistence`와 화면 준비 신호를 사용한다.
- [x] 테스트 인증 모드가 실제 API 오류 alert를 만들지 않도록 fixture 범위를 완성한다.
- [x] 대상 UI 테스트에서 `screen.*`, `tab.*`, `todo.add` 식별자가 XCUI 요소로 노출된다.
- [x] guest 로그인 UI 테스트가 세션 쿠키·네트워크 상태와 무관한 Debug 전용 초기 상태를 사용한다.
- [x] 한 테스트가 생성한 데이터가 다음 테스트에 영향을 주지 않는다.
- [x] 실패 시 screenshot, UI hierarchy와 로그를 결과 번들에 보존한다.
- [x] 최신 전체 suite를 동일 시뮬레이터에서 최소 3회 연속 통과시킨다.
- [x] iPhone 13 mini와 iPhone 16 Pro destination에서 핵심 UI 테스트를 각각 실행한다.
- [x] locale·theme 스모크 테스트를 데이터 기반으로 확장한다.
- [x] `simctl ui ... content_size`로 기본·최대 Dynamic Type을 명시하고 조합별 텍스트 frame을 xcresult에 보존한다.
- [ ] 접근성 식별자가 시각적 텍스트에 의존하지 않도록 유지한다.

2026-08-13 실제 실패 xcresult에서 UI Snapshot·screen recording attachment, 앱 UI hierarchy와 XCTest activity/test log를
추출·검토해 `screen.home`은 렌더됐지만 `tab.home` identifier 전파가 늦어진 원인을 진단했다. 이는 자동 실패 증거가
결과 번들에 보존되고 활용 가능한지 확인한 것이며 수동 시각·접근성 QA 완료를 의미하지 않는다.

`-ui-testing-authenticated`는 Home·Calendar·Todo·Team·Settings의 최소 empty fixture를 앱 시작마다 다시 구성하고,
알림 polling/refresh, APNs activation/resume, AI 동의 refresh와 pending push 처리를 no-op으로 만든다. 앱의 모든 직접
HTTP 경로가 모이는 `APIClient.perform`에는 같은 Debug 실행 모드에서 요청이 하나라도 발생하면 즉시 종료하는 fail-fast를
적용했다. 따라서 iPhone 16 Pro UI target 3회 연속 4/4 및 iPhone 13 mini 1회 4/4 통과는 alert 순간 부재뿐 아니라
현재 자동 UI 범위의 실제 API 요청 0건도 검증한다. 각 authenticated 테스트는 5탭 또는 Todo·Settings 이동 뒤 alert 부재를
추가 확인하며, 서버 쓰기나 공유 fixture를 만들지 않는다. 일반 Debug와 Release 경로는 기존 동작을 유지한다.

Dynamic Type 재현 시 시뮬레이터를 부팅한 다음 `xcrun simctl ui <UDID> content_size large` 또는
`accessibility-extra-extra-extra-large`를 설정하고 같은 명령에서 크기 인자를 생략해 적용값을 조회한다.
이후 `xcodebuild ... test -only-testing:DutyparkUITests/DutyparkUITests/testLanguageAndThemePreferencesAcrossSupportedCombinations`를
실행하고 끝나면 원래 값으로 복원한다. 이 절차는 앱 launch argument로 글자 크기를 가정하지 않고
시뮬레이터의 실제 설정값과 XCUI frame을 교차 확인한다.

## 완료 조건

- [ ] iPhone 전용·세로 방향 지원 범위가 프로젝트, 스토어 정보와 테스트 계획에 일치한다.
- [x] iPhone 전용·세로 방향 기술 설정이 프로젝트와 unsigned generic iOS Release Archive에서 일치한다.
- [ ] iPhone 13 mini와 iPhone 16 Pro에서 핵심 사용자 흐름이 통과한다.
- [ ] 2개 언어 × Light/Dark × 기본·최대 Dynamic Type 매트릭스가 기록되고 차단 결함이 없다.
- [ ] VoiceOver로 캘린더와 Todo 이동을 포함한 핵심 기능을 완료할 수 있다.
- [ ] 주요 조작의 44pt 터치 영역이 수동·자동 테스트에서 확인된다.
- [ ] Todo 드래그와 기능적으로 동등한 접근성 대체 조작이 검증된다.
- [ ] 오프라인, 느린 네트워크, 인증 오류와 5xx에서 크래시·데이터 유실·무한 재시도가 없다.
- [x] 탭·`todo.add`·로그인 대상 UI 실패가 재발하지 않고 최신 전체 265개 테스트가 3회 연속 통과한다.

2026-08-13 `Dutypark QA iPhone 16 Pro`(iOS 26.5) 시뮬레이터에서 UI 테스트 3개를 포함한 당시 전체 suite를
새로 3회 연속 실행해 매번 **263/263**(실패·건너뜀 0)으로 통과했다. iPhone 13 mini(iOS 26.5)에서도
UI 테스트 3개를 포함한 전체 suite **263/263**이 1회 통과했다. iPhone 16 Pro의 5개 탭 이동 대상 테스트는
별도로 3회 연속, 알림·Todo 툴바 44pt 테스트는 별도로 1회 통과했다. 두 기기의 수동 화면·핵심 사용자 흐름·
접근성 매트릭스 검증은 아직 남아 있다. 이후 데이터 기반 UI smoke를 추가해 한국어·영어 × Light/Dark 4개 조합에서
`홈`/`Home` 탭 label과 `현재 테마: 라이트/다크`/`Current theme: Light/Dark` 설정 접근성 값을 검증했고,
최초 전체 suite 반복에서는 렌더된 홈·탭 UI에 identifier 전파가 늦어 첫 `ko` × Light가 실패했다. app foreground와
`screen.home` 준비를 bounded wait로 확인하도록 보정한 뒤 smoke는 iPhone 16 Pro에서 3회 연속, iPhone 13 mini에서
1회 통과했다. 안정화 후 iPhone 16 Pro 전체 suite도 UI 테스트 4개를 포함해 새로 3회 연속 **264/264**
(실패·건너뜀 0)로 통과했다. 이 시점의 기본·최대 Dynamic Type과 수동 시각·접근성 검증은 남아 있었다.

2026-08-13에 시뮬레이터의 실제 `content_size`를 `large`와
`accessibility-extra-extra-extra-large`로 바꿔 가며 2개 언어 × Light/Dark 8개 조합을 추가로 검증했다.
iPhone 16 Pro에서 기본·최대 스모크가 각각 3회 연속, iPhone 13 mini에서 각각 1회 통과했다.
설정 theme 텍스트 높이는 iPhone 16 Pro에서 기본 15.67pt, 최대 한국어 46.00pt(2.94배),
최대 영어 91.67pt(5.85배, 줄바꿈 포함)로 측정됐고 모든 조합의 frame을 xcresult attachment로 남겼다.
탭 아이콘에 고정 `tab.*` ID를 적용해 iOS 26.5의 accessibility button으로 안정적으로 전파했고,
보정 후 5탭 이동 테스트도 3회 연속 통과했다. 두 시뮬레이터는 원래 `large`로 복원했다.
변경 후 전체 suite는 iPhone 16 Pro에서 다시 3회 연속 **264/264**(실패·건너뜀 0)로 통과했고
Release Simulator clean build도 성공했다. 전체 화면 clipping·VoiceOver·기능 완주 수동 검증은 아직 남아 있다.

이후 `LocalizationCatalogTests`의 Swift Testing 테스트 1개로 `#filePath`에서 찾은
`Dutypark/Resources/*.xcstrings` **정확히 8개**를 검사했다. 번역 대상 695개 table/key 항목에 대해
한국어·영어 source state가 translated이고 값이 비어 있거나 key와 같지 않은지, table/key가 중복되지 않는지,
컴파일된 Bundle lookup이 source와 정확히 같은지 확인한다. printf placeholder는 위치 지정·비지정 여부와 타입이
언어 간 일치하는지 검사하되 `%%`는 제외한다. 현재 `shouldTranslate = false` 항목은 0개다. 대상 테스트는
iPhone 16 Pro(iOS 26.5)에서 **1/1**, 전체 suite는 **265/265**(실패·건너뜀 0)로 3회 연속 통과했고 Release
Simulator clean build도 성공했다. 새 unsigned generic iOS Release Archive에는 8개 compiled table 모두
`en.lproj`·`ko.lproj`가 있으며 각 locale의 table별 key 수는 source와 같은 **31, 99, 57, 46, 22, 211,
67, 162개**다. 제한된 Swift source hardcoded-string 감사에서는 명확한 사용자 노출 결함을 찾지 못했지만,
방어적 영문 `Errors` fallback과 Todo의 `": "` 문장부호 결합은 저위험 후속 검토로 남긴다. 이 검증은 다른 feature
catalog, 모든 사용자 노출 문자열, 수동 clipping·VoiceOver·시각 QA, 서명 Archive나 TestFlight 완료를 뜻하지 않는다.
