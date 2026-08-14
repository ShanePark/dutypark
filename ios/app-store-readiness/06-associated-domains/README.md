# Associated Domains와 Universal Links 출시 준비

## 현재 상태

- iOS entitlement에는 `applinks:dutypark.o-r.kr`가 선언돼 있다.
- Team ID는 `2V47G42CDS`, Bundle ID는 `io.github.shanepark.dutypark`, AASA app ID는 `2V47G42CDS.io.github.shanepark.dutypark`다.
- AASA JSON과 `/.well-known/apple-app-site-association`의 nginx 전용 경로는 저장소에 구현돼 있다.
- 남은 일은 해당 구성을 운영에 반영해 외부 응답을 확인하고, 새로 설치한 실제 iPhone에서 링크 동작을 검증하는 것이다.

## 남은 체크

### 운영 AASA

- [ ] `https://dutypark.o-r.kr/.well-known/apple-app-site-association`를 운영에 배포한다.
- [ ] 외부 네트워크에서 redirect 없는 HTTP 200, `application/json`, 유효한 JSON 본문을 확인한다.
- [ ] SPA HTML fallback, 인증 요구, WAF·봇 차단과 지역 제한이 AASA 응답에 개입하지 않는지 확인한다.
- [ ] CDN/reverse proxy에 남은 과거 HTML 캐시를 제거하고 Apple CDN 전파 뒤 다시 확인한다.
- [ ] 실제 지원 path가 AASA의 최소 범위와 일치하는지 최종 확인한다.

### 실제 iPhone

- [ ] AASA 배포 뒤 기존 앱을 삭제하고 Release 또는 TestFlight 앱을 새로 설치한다.
- [ ] 메모·메시지·메일 등 외부 앱에서 지원 링크를 탭해 의도한 앱 화면으로 이동하는지 확인한다.
- [ ] 로그인 전 링크를 열어 로그인한 뒤 원래 목적 화면으로 복귀하는지 확인한다.
- [ ] 앱 미설치 상태와 미지원 path가 정상 웹 화면으로 fallback되는지 확인한다.
- [ ] 검증한 URL, 앱 빌드와 결과를 출시 기록에 남긴다.

## 완료 조건

- 운영 AASA가 외부에서 redirect 없이 HTTP 200 JSON을 반환한다.
- AASA의 app ID와 지원 path가 최종 서명 앱의 Team ID·Bundle ID 및 라우팅 범위와 일치한다.
- 새로 설치한 실제 iPhone에서 지원 링크, 로그인 후 복귀와 웹 fallback이 모두 동작한다.

## 불변 계약

- AASA 파일명에는 `.json` 확장자를 붙이지 않는다.
- AASA 경로는 인증과 SPA fallback보다 우선하며 HTML을 반환하지 않는다.
- `appIDs`는 `2V47G42CDS.io.github.shanepark.dutypark`를 사용한다.
- 앱은 명시적으로 지원하는 path만 가로채고, 미지원 링크는 웹으로 안전하게 남긴다.
- Safari 주소창 직접 입력만으로 Universal Links 검증을 대체하지 않는다.

## 필요한 실행 및 참고

운영 배포 뒤 다음 응답의 status, `Content-Type`, `Location` 헤더와 본문을 확인한다.

```bash
curl -i https://dutypark.o-r.kr/.well-known/apple-app-site-association
```

- entitlement: [Dutypark.entitlements](../../Dutypark/Dutypark.entitlements)
- Xcode 설정: [project.pbxproj](../../Dutypark.xcodeproj/project.pbxproj)
- [Apple: Supporting associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains)
- [Apple: Supporting universal links](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app)
- [Apple: Establishing associated domains](https://developer.apple.com/documentation/xcode/establishing-your-app-s-associated-domains)
