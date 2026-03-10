package com.tistory.shanepark.dutypark.security.controller

import tools.jackson.core.type.TypeReference
import tools.jackson.databind.json.JsonMapper
import com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.policy.domain.enums.PolicyType
import com.tistory.shanepark.dutypark.member.service.ConsentService
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.SsoSignupRequest
import com.tistory.shanepark.dutypark.security.oauth.kakao.KakaoLoginService
import com.tistory.shanepark.dutypark.security.oauth.naver.NaverLoginService
import com.tistory.shanepark.dutypark.security.oauth.SocialAccountAlreadyLinkedException
import com.tistory.shanepark.dutypark.security.service.AuthService
import com.tistory.shanepark.dutypark.security.service.CookieService
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*
import org.springframework.web.util.UriComponentsBuilder
import java.net.URI
import java.nio.charset.StandardCharsets
import java.util.Base64

@RestController
@RequestMapping("/api/auth")
class OAuthController(
    private val kakaoLoginService: KakaoLoginService,
    private val naverLoginService: NaverLoginService,
    private val memberService: MemberService,
    private val authService: AuthService,
    private val cookieService: CookieService,
    private val consentService: ConsentService,
) {
    private val jsonMapper = JsonMapper.builder().build()

    companion object {
        private const val SOCIAL_LINK_ERROR_ALREADY_LINKED = "already_linked"
    }

    @GetMapping("Oauth2ClientCallback/kakao")
    fun kakaoLoginCallback(
        @RequestParam code: String,
        @RequestParam(value = "state") stateString: String,
        httpServletRequest: HttpServletRequest,
        httpServletResponse: HttpServletResponse,
        @Login(required = false) loginMember: LoginMember?
    ): ResponseEntity<Void> {
        val state = parseState(stateString)
        val referer = (state["referer"] as String?) ?: "/"

        val redirectUrl = httpServletRequest.requestURL.toString()

        val login = (state["login"] as Boolean?) ?: false
        if (login && loginMember != null) {
            return try {
                kakaoLoginService.setKakaoIdToMember(
                    code = code,
                    redirectUrl = redirectUrl,
                    loginMember = loginMember,
                )
                ResponseEntity.status(HttpStatus.FOUND)
                    .location(URI.create(referer))
                    .build()
            } catch (e: SocialAccountAlreadyLinkedException) {
                ResponseEntity.status(HttpStatus.FOUND)
                    .location(buildSocialLinkErrorUri(referer, e.provider))
                    .build()
            }
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

    @GetMapping("Oauth2ClientCallback/naver")
    fun naverLoginCallback(
        @RequestParam code: String,
        @RequestParam(value = "state") stateString: String,
        httpServletRequest: HttpServletRequest,
        httpServletResponse: HttpServletResponse,
        @Login(required = false) loginMember: LoginMember?
    ): ResponseEntity<Void> {
        val state = parseState(stateString)
        val referer = (state["referer"] as String?) ?: "/"

        val login = (state["login"] as Boolean?) ?: false
        if (login && loginMember != null) {
            return try {
                naverLoginService.setNaverIdToMember(
                    code = code,
                    state = stateString,
                    loginMember = loginMember,
                )
                ResponseEntity.status(HttpStatus.FOUND)
                    .location(URI.create(referer))
                    .build()
            } catch (e: SocialAccountAlreadyLinkedException) {
                ResponseEntity.status(HttpStatus.FOUND)
                    .location(buildSocialLinkErrorUri(referer, e.provider))
                    .build()
            }
        }

        val callbackUrl = state["callbackUrl"] as String?
            ?: throw IllegalArgumentException("callbackUrl is required in state")
        return naverLoginService.login(
            req = httpServletRequest,
            resp = httpServletResponse,
            code = code,
            state = stateString,
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
        val termsVersion = request.termsVersion?.takeIf { it.isNotBlank() } ?: return ResponseEntity.badRequest().build()
        val privacyVersion = request.privacyVersion?.takeIf { it.isNotBlank() } ?: return ResponseEntity.badRequest().build()

        val member = memberService.createSsoMember(
            username = request.username,
            memberSsoRegisterUUID = request.uuid
        )

        val ipAddress = httpServletRequest.remoteAddr
        val userAgent = httpServletRequest.getHeader("User-Agent")

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

    private fun parseState(stateString: String): Map<String, Any> {
        return try {
            jsonMapper.readValue(stateString, object : TypeReference<Map<String, Any>>() {})
        } catch (_: Exception) {
            val normalized = stateString
                .replace('-', '+')
                .replace('_', '/')
                .let { raw ->
                    val padding = (4 - raw.length % 4) % 4
                    raw + "=".repeat(padding)
                }
            val decoded = String(Base64.getDecoder().decode(normalized), StandardCharsets.UTF_8)
            jsonMapper.readValue(decoded, object : TypeReference<Map<String, Any>>() {})
        }
    }

    private fun buildSocialLinkErrorUri(referer: String, provider: SsoType): URI {
        return UriComponentsBuilder.fromUriString(referer)
            .replaceQueryParam("socialLinkError", SOCIAL_LINK_ERROR_ALREADY_LINKED)
            .replaceQueryParam("socialProvider", provider.name.lowercase())
            .build(true)
            .toUri()
    }

}
