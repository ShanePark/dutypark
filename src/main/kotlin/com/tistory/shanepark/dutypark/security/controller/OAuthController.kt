package com.tistory.shanepark.dutypark.security.controller

import com.fasterxml.jackson.databind.ObjectMapper
import com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.SsoSignupRequest
import com.tistory.shanepark.dutypark.security.domain.dto.TokenResponse
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

        val spaCallbackUrl = (state["spaCallbackUrl"] as String?) ?: "http://localhost:5173/auth/oauth-callback"
        val originalRedirectUri = (state["redirectUri"] as String?) ?: redirectUrl
        return kakaoLoginService.loginForSpa(
            req = httpServletRequest,
            code = code,
            redirectUrl = originalRedirectUri,
            spaCallbackUrl = spaCallbackUrl
        )
    }

    @PostMapping("sso/signup/token")
    @SlackNotification
    fun ssoSignupForSpa(
        @RequestBody request: SsoSignupRequest,
        httpServletRequest: HttpServletRequest
    ): ResponseEntity<TokenResponse> {
        if (!request.termAgree) {
            return ResponseEntity.badRequest().build()
        }

        val member = memberService.createSsoMember(
            username = request.username,
            memberSsoRegisterUUID = request.uuid
        )

        val tokenResponse = authService.getTokenResponseByMemberId(
            memberId = member.id!!,
            req = httpServletRequest
        )

        return ResponseEntity.ok(tokenResponse)
    }

}
