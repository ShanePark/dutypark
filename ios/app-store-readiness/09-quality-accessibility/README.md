# 품질, 호환성 및 접근성 검증 가이드

최종 확인일: 2026-08-12

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
- 현지화 선택 로직: [AppLocalization.swift](../../Dutypark/Core/Localization/AppLocalization.swift)

## 1. 공식 지원 범위

- [x] 프로젝트 대상은 iPhone 전용(`TARGETED_DEVICE_FAMILY = 1`)이다.
- [x] iPhone 지원 방향은 세로(`UIInterfaceOrientationPortrait`)로 제한되어 있다.
- [x] 최소 지원 버전은 iOS 17이다.
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

지원 언어는 한국어, 영어, 일본어, 중국어 간체, 스페인어의 5개다.
모든 조합을 완전 탐색하기 어려우면 핵심 화면은 전 조합, 나머지 화면은 pairwise 방식으로 기록한다.

- [ ] `ko` × Light × 기본/최대 Dynamic Type
- [ ] `ko` × Dark × 기본/최대 Dynamic Type
- [ ] `en` × Light × 기본/최대 Dynamic Type
- [ ] `en` × Dark × 기본/최대 Dynamic Type
- [ ] `ja` × Light × 기본/최대 Dynamic Type
- [ ] `ja` × Dark × 기본/최대 Dynamic Type
- [ ] `zh-Hans` × Light × 기본/최대 Dynamic Type
- [ ] `zh-Hans` × Dark × 기본/최대 Dynamic Type
- [ ] `es` × Light × 기본/최대 Dynamic Type
- [ ] `es` × Dark × 기본/최대 Dynamic Type
- [ ] 모든 사용자 노출 문자열이 번역되고 키 이름이 그대로 보이지 않는다.
- [ ] 긴 영어·스페인어 문자열이 버튼, 탭, 경고창에서 잘리지 않는다.
- [ ] 일본어·중국어의 줄바꿈이 아이콘이나 상태 배지를 침범하지 않는다.
- [ ] Dark Mode에서 텍스트, 경계선, disabled 상태와 오류 메시지가 구분된다.
- [ ] 최대 Dynamic Type에서 확대, 줄바꿈 또는 스크롤로 기능을 끝까지 수행할 수 있다.
- [ ] 고정 높이 때문에 텍스트가 잘리는 화면을 기록하고 수정한다.

Dynamic Type 검증 기준은 [Apple의 글자 크기 지원 안내](https://developer.apple.com/documentation/uikit/scaling-fonts-automatically)를 참고한다.

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
- [ ] [DutyparkUITests.swift](../../DutyparkUITests/DutyparkUITests.swift)의 터치 영역 테스트를 안정화한다.
- [ ] 현재 실패하는 `todo.add` 요소가 XCUI에서 안정적으로 발견되고 44pt 이상으로 측정된다.

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

- [ ] 각 테스트는 언어, 테마, 인증 상태와 테스트 데이터를 명시적으로 초기화한다.
- [ ] 고정 sleep 대신 `waitForExistence`와 화면 준비 신호를 사용한다.
- [ ] 테스트 인증 모드가 실제 API 오류 alert를 만들지 않도록 fixture 범위를 완성한다.
- [ ] `screen.*`, `tab.*`, `todo.add` 식별자가 렌더링 구조 변화에도 유지된다.
- [ ] 한 테스트가 생성한 데이터가 다음 테스트에 영향을 주지 않는다.
- [ ] 실패 시 screenshot, UI hierarchy와 로그를 결과 번들에 보존한다.
- [ ] 동일 시뮬레이터에서 전체 테스트를 최소 3회 연속 통과시킨다.
- [ ] iPhone 13 mini와 iPhone 16 Pro destination에서 핵심 UI 테스트를 각각 실행한다.
- [ ] locale·theme 스모크 테스트를 데이터 기반으로 확장한다.
- [ ] 접근성 식별자가 시각적 텍스트에 의존하지 않도록 유지한다.

## 완료 조건

- [ ] iPhone 전용·세로 방향 지원 범위가 프로젝트, 스토어 정보와 테스트 계획에 일치한다.
- [ ] iPhone 13 mini와 iPhone 16 Pro에서 핵심 사용자 흐름이 통과한다.
- [ ] 5개 언어 × Light/Dark × 기본·최대 Dynamic Type 매트릭스가 기록되고 차단 결함이 없다.
- [ ] VoiceOver로 캘린더와 Todo 이동을 포함한 핵심 기능을 완료할 수 있다.
- [ ] 주요 조작의 44pt 터치 영역이 수동·자동 테스트에서 확인된다.
- [ ] Todo 드래그와 기능적으로 동등한 접근성 대체 조작이 검증된다.
- [ ] 오프라인, 느린 네트워크, 인증 오류와 5xx에서 크래시·데이터 유실·무한 재시도가 없다.
- [ ] `todo.add` 실패를 포함한 UI 테스트가 수정되고 전체 176개 테스트가 안정적으로 통과한다.
