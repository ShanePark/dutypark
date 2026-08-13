# Associated Domains와 Universal Links

## 목표

Dutypark의 웹 링크를 iOS 앱으로 안전하게 연결하고, App Store 제출 전에 운영 환경에서 Universal Links가 실제로 동작함을 검증한다.

이 문서는 앱의 entitlement 설정과 운영 서버의 AASA(Apple App Site Association) 제공 상태를 함께 다룬다.

## 현재 상태

- iOS 프로젝트에는 Associated Domains entitlement가 이미 존재한다.
- 관련 파일: [`ios/Dutypark/Dutypark.entitlements`](../../Dutypark/Dutypark.entitlements)
- 현재 Xcode Bundle ID는 `com.tistory.shanepark.dutypark`이고 출시 목표 후보는 `io.github.shanepark.dutypark`다. Apple 승인 후 Explicit App ID 가용성 확인 전까지 출시 식별자는 미확정이다.
- 2026-08-12 확인 기준, 운영 AASA URL은 HTTP 200을 반환하지만 `Content-Type: text/html`인 SPA HTML을 응답한다.
- 따라서 현재 응답은 유효한 AASA JSON으로 인정될 수 없으며 Universal Links 설치 검증이 실패할 가능성이 높다.
- HTTP 상태 코드가 200이라는 사실만으로 설정 완료로 판단하면 안 된다.

## 해야 할 일

- [ ] Apple Developer 계정의 실제 Team ID를 확인한다.
- [ ] Xcode 프로젝트의 Bundle ID를 확인한다.
- [ ] `TeamID.BundleID` 형태의 `appID` 값을 확정한다.
- [ ] entitlement의 `applinks:` 도메인이 운영 도메인과 정확히 일치하는지 확인한다.
- [ ] 운영 서버에서 AASA JSON을 제공한다.
- [ ] AASA URL이 SPA fallback 또는 로그인 화면으로 전달되지 않도록 한다.
- [ ] AASA 응답에 redirect가 없는지 확인한다.
- [ ] 올바른 Content-Type을 반환하도록 설정한다.
- [ ] CDN과 reverse proxy의 캐시·라우팅 규칙을 확인한다.
- [ ] 앱이 처리할 URL path 범위를 최소 권한으로 정의한다.
- [ ] 실제 기기에 앱을 새로 설치한 뒤 링크 진입을 검증한다.

## AASA 제공 경로

Apple은 다음 경로 중 하나에서 AASA 파일을 조회한다.

- `https://<운영도메인>/.well-known/apple-app-site-association`
- `https://<운영도메인>/apple-app-site-association`

파일명에 `.json` 확장자를 붙이지 않는다.

두 경로를 모두 제공할 필요는 없지만, 운영·프록시 구성이 명확한 `.well-known` 경로를 권장한다.

## AASA 응답 요구사항

- HTTP 200을 반환한다.
- 응답 본문은 HTML이 아닌 유효한 JSON이다.
- redirect 없이 최종 JSON을 직접 반환한다.
- 인증 쿠키나 로그인 세션을 요구하지 않는다.
- `Content-Type`은 `application/json`을 사용한다.
- UTF-8 JSON이며 HTML 주석, BOM, 템플릿 문구를 포함하지 않는다.
- Apple CDN과 외부 네트워크에서 접근 가능해야 한다.
- WAF, 봇 차단, 국가 제한이 Apple의 조회를 막지 않아야 한다.

## AASA 예시

실제 값이 확정되기 전에는 아래 placeholder를 운영에 배포하지 않는다.

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": [
          "TEAM_ID.io.github.shanepark.dutypark"
        ],
        "components": [
          {
            "/": "/<APP_LINK_PATH>/*",
            "comment": "Dutypark 앱에서 처리할 링크"
          }
        ]
      }
    ]
  }
}
```

위 `appID`의 `TEAM_ID`는 placeholder이며 전체 값은 출시 목표 후보를 반영한 **승인 대기 값**이다. Apple 멤버십 승인 후 `io.github.shanepark.dutypark`의 Explicit App ID 가용성과 실제 Team ID를 확인한 뒤 확정하고, 사용할 수 없다면 AASA를 배포하기 전에 새 Bundle ID로 바꾼다. path도 현재 라우팅 설정을 확인해 실제 값으로 채운다.

## 서버와 CDN 점검

SPA 서버는 존재하지 않는 경로를 `index.html`로 돌려주는 경우가 많다.

AASA 경로는 SPA fallback보다 우선하는 정적 JSON 또는 전용 endpoint로 등록해야 한다.

CDN을 사용한다면 다음 항목을 별도로 확인한다.

- AASA 경로의 origin routing
- JSON Content-Type 유지 여부
- 301/302/307/308 redirect 여부
- 캐시된 과거 HTML 응답 제거 여부
- 압축 후 본문 손상 여부
- 배포 직후 CDN 전파 지연

Apple CDN은 AASA 응답을 캐시할 수 있으므로 서버 수정 직후 결과가 즉시 반영되지 않을 수 있다.

## 명령줄 검증

운영 배포 후 다음 형태로 점검한다.

```bash
curl -i https://<운영도메인>/.well-known/apple-app-site-association
```

확인할 결과는 다음과 같다.

- 상태 코드가 200이다.
- `Content-Type`이 `application/json`이다.
- `Location` 헤더가 없다.
- 본문이 `{`로 시작하는 유효한 JSON이다.
- 본문에 `<!doctype html>` 또는 SPA root markup이 없다.
- `appIDs` 값이 실제 `TeamID.BundleID`와 정확히 일치한다.

## 실기기 테스트

Universal Links 최종 검증은 Simulator만으로 끝내지 않고 실제 iPhone에서 수행한다.

1. AASA를 먼저 운영에 배포한다.
2. 기기에서 기존 Dutypark 앱을 삭제한다.
3. Xcode 또는 TestFlight로 앱을 새로 설치한다.
4. Safari 주소창 직접 입력뿐 아니라 메모·메시지·메일의 링크 탭도 시험한다.
5. 대상 링크가 앱의 의도한 화면으로 열리는지 확인한다.
6. 앱 미설치 상태에서는 동일 링크가 정상 웹 화면으로 열리는지 확인한다.
7. 앱 내부에서 미지원 path를 받았을 때 안전한 fallback이 동작하는지 확인한다.
8. 로그인 전 링크를 열고 로그인한 뒤 목적 화면으로 복귀하는지 확인한다.

Safari 주소창에서 직접 입력한 동작은 링크 탭 동작과 다를 수 있으므로 외부 앱에서의 탭 테스트를 반드시 포함한다.

## 완료 조건

- [ ] entitlement에 올바른 `applinks:<운영도메인>` 값이 포함되어 있다.
- [ ] AASA의 `appIDs`가 실제 Team ID와 Bundle ID 조합이다.
- [ ] 운영 AASA가 redirect 없이 HTTP 200 JSON을 반환한다.
- [ ] Content-Type이 `application/json`이다.
- [ ] SPA HTML이 AASA 경로에 반환되지 않는다.
- [ ] CDN 캐시 갱신 후 외부 네트워크에서도 동일 응답을 확인했다.
- [ ] 새로 설치한 실제 iPhone에서 지원 링크가 앱의 목적 화면으로 열린다.
- [ ] 앱 미설치 및 미지원 path의 웹 fallback도 정상이다.
- [ ] 검증 결과와 테스트한 URL을 배포 체크 기록에 남겼다.

## 공식 문서

- [Apple: Supporting associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains)
- [Apple: Supporting universal links in your app](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app)
- [Apple: Establishing your app's associated domains](https://developer.apple.com/documentation/xcode/establishing-your-app-s-associated-domains)
