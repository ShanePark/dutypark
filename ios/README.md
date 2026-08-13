# Dutypark iOS

Dutypark의 iPhone 전용 SwiftUI 앱입니다. 웹/PWA의 다섯 기본 탭 구조를 기준으로 기능을 네이티브 화면에 순차적으로 옮깁니다.

## 요구 사항

- Xcode 26 이상
- iOS 17 이상
- Swift 6

## 열기와 검증

`Dutypark.xcodeproj`를 Xcode에서 열거나 다음 명령을 사용합니다.

```sh
xcodebuild \
  -project Dutypark.xcodeproj \
  -scheme Dutypark \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  build
```

단위 테스트는 설치된 iPhone 시뮬레이터 이름을 지정해 실행합니다.

```sh
xcodebuild \
  -project Dutypark.xcodeproj \
  -scheme Dutypark \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  test
```

## 프로젝트 구조

- `Dutypark/App`: 앱 시작점과 루트 내비게이션
- `Dutypark/Core`: 앱 공통 기반
- `Dutypark/Domain`: 공통 도메인 타입
- `Dutypark/Features`: 화면별 기능
- `Dutypark/Components`: 공통 SwiftUI 컴포넌트
- `Dutypark/Resources`: String Catalog와 향후 앱 자산
- `Dutypark/Config`: 빌드 환경 구분 기반
- `DutyparkTests`: 단위 테스트
- `DutyparkUITests`: UI 테스트

Xcode 프로젝트는 filesystem-synchronized groups를 사용합니다. 위 소스 디렉터리에 파일을 추가할 때 일반적으로 `project.pbxproj`를 수정할 필요가 없습니다.

## 서명 전 확인

현재 Xcode 프로젝트의 개발용 번들 식별자는 서버 패키지 관례를 따른 `com.tistory.shanepark.dutypark`입니다. 출시 목표 번들 식별자는 `io.github.shanepark.dutypark`를 우선 후보로 하지만, Apple Developer Program 승인 후 Explicit App ID 등록 화면에서 가용성을 확인하기 전에는 최종 확정하지 않습니다.

Apple Developer Program은 개인 주체로 가입하고 결제를 완료했으며 현재 Apple 승인을 기다리는 중입니다. 승인 후 유료 개인 Developer Team과 Team ID를 확인하고, 목표 Bundle ID가 사용 가능하면 Xcode·App Store Connect·APNs topic·AASA를 함께 변경해야 합니다. 개인 멤버십으로 출시할 때 App Store 판매자명에는 계정 소유자의 법적 실명이 표시될 수 있습니다.
