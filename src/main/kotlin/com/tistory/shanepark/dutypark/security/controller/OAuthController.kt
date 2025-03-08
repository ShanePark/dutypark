package com.tistory.shanepark.dutypark.security.controller

import com.fasterxml.jackson.databind.ObjectMapper
import com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.oauth.kakao.KakaoLoginService
import com.tistory.shanepark.dutypark.security.service.AuthService
import jakarta.servlet.http.HttpServletRequest
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*
import java.net.URI

@RestController
@RequestMapping("/api/auth")
class OAuthController(
    private val kakaoLoginService: KakaoLoginService,
    private val memberService: MemberService,
    private val authService: AuthService,
) {
    private val objectMapper = ObjectMapper()

    @GetMapping("Oauth2ClientCallback/kakao")
    fun kakaoLoginCallback(
        @RequestParam code: String,
        @RequestParam(value = "state") stateString: String,
        httpServletRequest: HttpServletRequest,
        @Login(required = false) loginMember: LoginMember?
    ): ResponseEntity<Void> {
        val state = objectMapper.readValue(stateString, Map::class.java)
        val referer = (state["referer"] as String?) ?: "/"

        val redirectUrl = httpServletRequest.requestURL.toString()

        val login = (state["login"] as Boolean?) ?: false
        if (login && loginMember != null) {
            kakaoLoginService.setKakaoIdToMember(
                code = code,
                redirectUrl = redirectUrl,
                loginMember = loginMember,
            )
            return ResponseEntity.status(HttpStatus.FOUND)
                .location(URI.create(referer))
                .build()
        }

        return kakaoLoginService.login(
            code = code,
            redirectUrl = redirectUrl,
            referer = referer,
            req = httpServletRequest
        )
    }

    @PostMapping("sso/signup")
    @SlackNotification
    fun ssoSignup(
        @RequestParam uuid: String,
        @RequestParam(value = "username") username: String,
        @RequestParam(value = "term_agree") termAgree: Boolean,
        httpServletRequest: HttpServletRequest
    ): ResponseEntity<Void> {
        if (!termAgree) {
            return ResponseEntity.badRequest().build()
        }

        val member = memberService.createSsoMember(username = username, memberSsoRegisterUUID = uuid)

        val loginCookieHeaders = authService.getLoginCookieHeaders(
            memberId = member.id,
            req = httpServletRequest,
        )

        return ResponseEntity
            .status(HttpStatus.FOUND)
            .headers(loginCookieHeaders)
            .location(URI.create("/auth/sso-congrats"))
            .build()
    }

}
