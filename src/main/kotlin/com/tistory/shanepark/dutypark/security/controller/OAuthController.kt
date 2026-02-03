package com.tistory.shanepark.dutypark.security.controller

import tools.jackson.databind.json.JsonMapper
import com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.policy.domain.enums.PolicyType
import com.tistory.shanepark.dutypark.member.service.ConsentService
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.SsoSignupRequest
import com.tistory.shanepark.dutypark.security.oauth.kakao.KakaoLoginService
import com.tistory.shanepark.dutypark.security.service.AuthService
import com.tistory.shanepark.dutypark.security.service.CookieService
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
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
    private val cookieService: CookieService,
    private val consentService: ConsentService,
) {
    private val jsonMapper = JsonMapper.builder().build()

    @GetMapping("Oauth2ClientCallback/kakao")
    fun kakaoLoginCallback(
        @RequestParam code: String,
        @RequestParam(value = "state") stateString: String,
        httpServletRequest: HttpServletRequest,
        httpServletResponse: HttpServletResponse,
        @Login(required = false) loginMember: LoginMember?
    ): ResponseEntity<Void> {
        val state = jsonMapper.readValue(stateString, Map::class.java)
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

        val callbackUrl = state["callbackUrl"] as String?
            ?: throw IllegalArgumentException("callbackUrl is required in state")
        return kakaoLoginService.login(
            req = httpServletRequest,
            resp = httpServletResponse,
            code = code,
            redirectUrl = redirectUrl,
            callbackUrl = callbackUrl
        )
    }

    @PostMapping("sso/signup/token")
    @SlackNotification
    fun ssoSignup(
        @RequestBody request: SsoSignupRequest,
        httpServletRequest: HttpServletRequest,
        httpServletResponse: HttpServletResponse
    ): ResponseEntity<Map<String, Any>> {
        if (!request.termAgree || !request.privacyAgree) {
            return ResponseEntity.badRequest().build()
        }

        val member = memberService.createSsoMember(
            username = request.username,
            memberSsoRegisterUUID = request.uuid
        )

        val ipAddress = httpServletRequest.remoteAddr
        val userAgent = httpServletRequest.getHeader("User-Agent")

        val termsVersion = request.termsVersion ?: "2025-01-15"
        val privacyVersion = request.privacyVersion ?: "2025-01-15"

        consentService.recordConsent(
            member = member,
            policyType = PolicyType.TERMS,
            consentVersion = termsVersion,
            ipAddress = ipAddress,
            userAgent = userAgent
        )
        consentService.recordConsent(
            member = member,
            policyType = PolicyType.PRIVACY,
            consentVersion = privacyVersion,
            ipAddress = ipAddress,
            userAgent = userAgent
        )

        val tokenResponse = authService.getTokenResponseByMemberId(
            memberId = member.id!!,
            req = httpServletRequest
        )

        cookieService.setTokenCookies(httpServletResponse, tokenResponse.accessToken, tokenResponse.refreshToken)

        return ResponseEntity.ok(
            mapOf(
                "expiresIn" to tokenResponse.expiresIn
            )
        )
    }

}
