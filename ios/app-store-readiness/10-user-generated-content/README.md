# 10. 사용자 생성 콘텐츠(UGC) 안전장치

- 기준일: 2026-08-12
- 상태: 설계 및 구현 필요
- 관련 심사 기준: [App Review Guidelines 1.2 — User-Generated Content](https://developer.apple.com/app-store/review/guidelines/#user-generated-content)
- 개인정보 기준: [App Review Guidelines 5.1 — Privacy](https://developer.apple.com/app-store/review/guidelines/#privacy)

## 판단 요약

Dutypark는 사용자가 일정, Todo, 사진과 첨부파일을 만들고 친구·가족·팀 구성원에게 공유할 수 있다.
공개 캘린더 링크도 있으므로 Apple이 이 기능을 사용자 생성 콘텐츠(UGC)로 판단할 가능성이 있다.
메신저나 익명 커뮤니티가 아니더라도 다른 사용자가 만든 텍스트·이미지·파일을 보는 구조라면 1.2 검토 대상이 될 수 있다.
따라서 “소규모 지인 공유”만을 근거로 안전장치를 생략하지 않는다.

현재 기능 근거:

- iOS 일정 화면: [CalendarView.swift](../../Dutypark/Features/Calendar/CalendarView.swift)
- iOS Todo 화면: [TodoView.swift](../../Dutypark/Features/Todo/TodoView.swift)
- iOS 첨부파일 갤러리: [AttachmentGallery.swift](../../Dutypark/Features/Attachments/AttachmentGallery.swift)
- 공개 캘린더: [GuestPublicCalendarView.swift](../../Dutypark/Features/Guest/GuestPublicCalendarView.swift)
- 친구 관계 UI: [SocialView.swift](../../Dutypark/Features/Social/SocialView.swift)
- 서버 일정 권한: [SchedulePermissionService.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/schedule/service/SchedulePermissionService.kt)
- 서버 첨부 권한: [AttachmentPermissionEvaluator.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/attachment/service/AttachmentPermissionEvaluator.kt)

## 출시 전 필수 체크리스트

- [ ] 부적절한 텍스트와 파일을 제한하는 이용 정책을 공개한다.
- [ ] 사용자가 노출된 콘텐츠를 앱 안에서 신고할 수 있다.
- [ ] 사용자가 가해 사용자를 앱 안에서 차단할 수 있다.
- [ ] 차단 즉시 해당 사용자의 공유 콘텐츠와 신규 상호작용이 숨겨진다.
- [ ] 운영자가 신고를 확인하고 콘텐츠·계정을 조치할 관리 수단이 있다.
- [ ] 지원 URL과 앱 안에 실제 연락 가능한 운영 연락처를 게시한다.
- [ ] 신고 접수·판단·조치·이의제기 절차와 SLA를 문서화한다.
- [ ] 정책 위반 콘텐츠가 공개 캘린더 캐시·첨부 저장소에서도 제거된다.
- [ ] 신고자 정보와 신고 사유는 최소 권한으로 보호한다.
- [ ] App Review Notes에 기능 위치와 테스트 절차를 제공한다.

## 1. 콘텐츠 필터

필터는 신고 기능의 대체가 아니라 첫 번째 방어선이다.

- 일정·Todo 제목과 설명의 길이, 제어문자, URL 등 기본 입력 검증을 서버에서 수행한다.
- 이미지·파일은 허용 MIME 형식, 확장자, 최대 크기와 개수를 서버에서 재검증한다.
- 실행 파일, 스크립트, 위장 확장자 및 확인되지 않은 콘텐츠 타입은 거부한다.
- 파일 다운로드 응답은 브라우저 실행보다 첨부 다운로드에 안전한 헤더를 사용한다.
- 공개 공유가 있는 콘텐츠에는 더 엄격한 입력·파일 정책을 적용한다.
- 자동 욕설 필터를 도입한다면 오탐 처리와 다국어 범위를 정책에 명시한다.
- 필터에 걸린 이유는 사용자에게 이해 가능한 문구로 제공하되 내부 탐지 규칙은 노출하지 않는다.

연관 구현 확인 위치:

- 첨부 검증: [AttachmentValidationService.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/attachment/service/AttachmentValidationService.kt)
- 첨부 API: [AttachmentController.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/attachment/controller/AttachmentController.kt)
- 일정 저장: [ScheduleService.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/schedule/service/ScheduleService.kt)
- Todo 저장: [TodoService.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/todo/service/TodoService.kt)

## 2. 콘텐츠 신고

콘텐츠 상세 또는 더보기 메뉴에 `신고` 동작을 둔다.
대상은 일정, Todo, 프로필 사진, 일정/Todo 첨부파일, 공개 캘린더 콘텐츠를 포함한다.

신고 데이터 최소 항목:

- 신고 ID, 신고자 ID, 대상 사용자 ID
- 대상 종류와 대상 ID, 신고 시점의 콘텐츠 스냅샷 또는 감사 가능한 참조
- 사유 코드(괴롭힘, 혐오, 성적 콘텐츠, 불법·위험, 스팸, 기타)
- 사용자 설명, 접수 시각, 처리 상태, 담당자와 처리 시각
- 조치 종류, 내부 메모, 신고자 통지 여부

요구 동작:

- 중복 탭에도 하나의 신고로 처리한다.
- 신고 직후 접수 완료와 예상 처리 시간을 알린다.
- 신고했다고 상대에게 신고자의 신원을 노출하지 않는다.
- 삭제된 콘텐츠도 운영 판단에 필요한 최소 감사 자료는 보존 정책에 따라 관리한다.
- 악의적 반복 신고에 대한 제한은 두되 정당한 신고 경로를 막지 않는다.

## 3. 사용자 차단

친구 삭제만으로는 Apple이 요구하는 “abusive users 차단”을 충족한다고 단정하기 어렵다.
차단은 별도 관계와 서버 권한 규칙으로 구현한다.

- 차단한 사용자의 일정·Todo·프로필·첨부파일을 모든 목록과 알림에서 숨긴다.
- 서로 친구 요청, 초대, 공유 및 알림 생성이 되지 않게 서버에서 차단한다.
- 기존 친구·공유 관계를 정리할지 제품 정책을 확정한다.
- 같은 팀 소속일 때 업무상 필수 데이터의 처리 방식을 별도로 정한다.
- 차단 목록 확인과 차단 해제를 설정에서 제공한다.
- 공개 링크는 로그아웃 상태에서도 열릴 수 있으므로 콘텐츠 자체의 게시 중단 수단이 필요하다.
- 클라이언트 숨김만 사용하지 말고 조회·검색·푸시 생성 단계에도 차단 규칙을 적용한다.

친구 관계 변경 시 [FriendService.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/member/service/FriendService.kt)의 권한·알림 회귀를 함께 확인한다.

## 4. 운영 연락처와 SLA

App Store Connect의 Support URL에는 로그인 없이 확인 가능한 지원 페이지를 등록한다.
앱 설정에도 이메일 또는 문의 폼 등 실제 응답 가능한 연락처를 표시한다.
검토 기간에만 존재하는 임시 연락처는 사용하지 않는다.

권장 초기 SLA:

- 긴급: 자해·폭력 위협, 아동 안전, 명백한 불법 콘텐츠 — 24시간 이내 1차 확인
- 높음: 성적 콘텐츠, 혐오, 반복 괴롭힘 — 24시간 이내 1차 확인
- 일반: 스팸, 불쾌한 콘텐츠, 기타 정책 위반 — 3영업일 이내 1차 확인
- 이의제기 — 5영업일 이내 재검토

SLA는 운영 가능한 수준으로 최종 확정하고, 담당자 부재 시 대체 담당자를 지정한다.
법적 긴급 요청, 증거 보존, 관계기관 신고가 필요한 상황의 내부 에스컬레이션도 정한다.

## 5. 이용 정책과 집행

정책에는 금지 콘텐츠, 계정 제재 단계, 콘텐츠 삭제, 반복 위반, 이의제기를 포함한다.
새 계정 가입과 앱 내 정책 화면에서 쉽게 접근할 수 있어야 한다.
정책 버전과 동의 이력은 현재 정책 구조를 재사용한다.

- iOS 정책 모델: [PolicyModels.swift](../../Dutypark/Domain/Models/PolicyModels.swift)
- 서버 정책 서비스: [PolicyService.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/policy/service/PolicyService.kt)
- iOS 정책 화면: [GuestPolicyView.swift](../../Dutypark/Features/Guest/GuestPolicyView.swift)

## 6. App Review Notes 초안

심사 노트에는 다음을 영어로 간결하게 적는다.

- 콘텐츠는 친구·가족·팀 단위로 공유되며 공개 링크 기능도 있다는 점
- 신고 버튼의 정확한 이동 경로와 신고 접수 후 동작
- 사용자 차단 버튼과 차단 목록·해제 경로
- 운영 연락처와 신고 처리 정책 URL
- 운영자 조치 화면 또는 백오피스의 존재
- 심사 계정 2개와 서로 공유된 테스트 콘텐츠 준비 방법
- 계정별 역할과 테스트용 팀 구성, 필요한 경우 공개 캘린더 URL

## 7. 테스트 시나리오

- [ ] 사용자 A가 만든 일정과 첨부를 사용자 B가 보고 신고한다.
- [ ] 신고가 한 번만 저장되고 운영자가 상태와 증거를 확인한다.
- [ ] 운영자 삭제 후 앱, 검색, 공개 링크, 캐시에서 대상이 더 이상 노출되지 않는다.
- [ ] 사용자 B가 A를 차단하면 양방향 공유·검색·친구 요청·알림이 중단된다.
- [ ] 차단 전 예약된 푸시도 전달되거나 배지에 남지 않는다.
- [ ] 차단 해제 후 정책에 정의한 관계만 복원된다.
- [ ] 팀원 차단, 팀 탈퇴, 친구 삭제, 계정 삭제가 충돌하지 않는다.
- [ ] 오프라인 신고 재시도와 중복 제출이 안전하다.
- [ ] 5개 지원 언어에서 사유와 안내 문구가 누락되지 않는다.
- [ ] VoiceOver로 신고·차단·취소·확인 버튼을 구분할 수 있다.
- [ ] iPhone 13 mini에서도 확인창과 사유 선택지가 잘리지 않는다.
- [ ] 일반 사용자가 다른 사람의 신고 내용이나 운영 메모를 조회할 수 없다.

## 완료 조건

- [ ] 필터, 신고, 차단, 운영 연락처 네 항목이 앱과 서버에서 실제 동작한다.
- [ ] 운영 정책과 SLA가 공개 문서 및 내부 절차에 반영되었다.
- [ ] 운영자가 신고를 조회하고 콘텐츠 또는 계정을 조치할 수 있다.
- [ ] 자동·수동 테스트에서 조회, 알림, 공개 링크 우회가 발견되지 않았다.
- [ ] App Review Notes와 심사 계정으로 기능을 재현할 수 있다.
- [ ] 정책·지원 URL이 운영 환경에서 로그인 없이 열린다.
