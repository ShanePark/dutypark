# TODO 첨부파일

### 1. 프런트엔드 리팩터링
- [x] 스케줄/TODO에서 겹치는 업로드/뷰어 로직을 공통 헬퍼(js 모듈)로 추출해 중복을 제거한다.
- [ ] 공통화 이후에도 브라우저 수동 테스트(업로드/저장/삭제/정렬)를 반복해 회귀를 확인한다.

### 2, 문제 수정
- [ ] Uppy 첨부 업로드가 동일 파일명을 추가하면 용량 초과 경고를 띄우는 문제(정확한 중복 안내 메시지를 노출하도록 수정 필요)
- [x] 스케쥴쪽 첨부파일 쪽에는 파일 다운로드 버튼이 있고 동작도 하는데 TODO 쪽의 파일첨부에는 다운로드 버튼이 없음
- [ ] 아래와 같은 오류 로그가 서버 로그에 계속 찍히는데 무슨 문제지? 
> 2025-11-16T01:45:00.687+09:00  WARN 918 --- [nio-8080-exec-6] .m.m.a.ExceptionHandlerExceptionResolver : Resolved [org.springframework.web.servlet.resource.NoResourceFoundException: No static resource .well-known/appspecific/com.chrome.devtools.json.]
2025-11-16T01:45:00.722+09:00  WARN 918 --- [nio-8080-exec-5] .m.m.a.ExceptionHandlerExceptionResolver : Resolved [org.springframework.web.servlet.resource.NoResourceFoundException: No static resource lib/pickr/pickr.min.js.map.]
2025-11-16T01:45:00.750+09:00  WARN 918 --- [nio-8080-exec-5] .m.m.a.ExceptionHandlerExceptionResolver : Resolved [org.springframework.web.servlet.resource.NoResourceFoundException: No static resource lib/uppy-5.1.7/uppy.min.mjs.map.]
2025-11-16T01:45:01.480+09:00  WARN 918 --- [nio-8080-exec-8] .m.m.a.ExceptionHandlerExceptionResolver : Resolved [org.springframework.web.servlet.resource.NoResourceFoundException: No static resource .well-known/appspecific/com.chrome.devtools.json.]
2025-11-16T01:45:01.518+09:00  WARN 918 --- [nio-8080-exec-3] .m.m.a.ExceptionHandlerExceptionResolver : Resolved [org.springframework.web.servlet.resource.NoResourceFoundException: No static resource lib/pickr/pickr.min.js.map.]
2025-11-16T01:45:01.547+09:00  WARN 918 --- [nio-8080-exec-2] .m.m.a.ExceptionHandlerExceptionResolver : Resolved [org.springframework.web.servlet.resource.NoResourceFoundException: No static resource lib/uppy-5.1.7/uppy.min.mjs.map.]
2025-11-16T01:45:07.007+09:00  WARN 918 --- [nio-8080-exec-3] .m.m.a.ExceptionHandlerExceptionResolver : Resolved [org.springframework.web.servlet.resource.NoResourceFoundException: No static resource .well-known/appspecific/com.chrome.devtools.json.]
2025-11-16T01:45:07.061+09:00  WARN 918 --- [io-8080-exec-10] .m.m.a.ExceptionHandlerExceptionResolver : Resolved [org.springframework.web.servlet.resource.NoResourceFoundException: No static resource lib/pickr/pickr.min.js.map.]
2025-11-16T01:45:07.071+09:00  WARN 918 --- [nio-8080-exec-6] .m.m.a.ExceptionHandlerExceptionResolver : Resolved [org.springframework.web.servlet.resource.NoResourceFoundException: No static resource lib/uppy-5.1.7/uppy.min.mjs.map.]
2025-11-16T01:45:08.018+09:00  WARN 918 --- [nio-8080-exec-6] .m.m.a.ExceptionHandlerExceptionResolver : Resolved [org.springframework.web.servlet.resource.NoResourceFoundException: No static resource .well-known/appspecific/com.chrome.devtools.json.]
2025-11-16T01:45:08.048+09:00  WARN 918 --- [nio-8080-exec-2] .m.m.a.ExceptionHandlerExceptionResolver : Resolved [org.springframework.web.servlet.resource.NoResourceFoundException: No static resource lib/pickr/pickr.min.js.map.]
2025-11-16T01:45:08.081+09:00  WARN 918 --- [io-8080-exec-10] .m.m.a.ExceptionHandlerExceptionResolver : Resolved [org.springframework.web.servlet.resource.NoResourceFoundException: No static resource lib/uppy-5.1.7/uppy.min.mjs.map.]
