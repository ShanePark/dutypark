package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.common.exceptions.BadRequestException
import com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.policy.domain.enums.PolicyType
import com.tistory.shanepark.dutypark.policy.service.PolicyService
import com.tistory.shanepark.dutypark.member.service.ConsentService
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.SsoSignupRequest
import com.tistory.shanepark.dutypark.security.oauth.kakao.KakaoLoginService
import com.tistory.shanepark.dutypark.security.oauth.naver.NaverLoginService
import com.tistory.shanepark.dutypark.security.oauth.SocialAccountAlreadyLinkedException
import com.tistory.shanepark.dutypark.security.oauth.web.WebOAuthAuthorizeRequest
import com.tistory.shanepark.dutypark.security.oauth.web.WebOAuthAuthorizeResponse
import com.tistory.shanepark.dutypark.security.oauth.web.WebOAuthPurpose
import com.tistory.shanepark.dutypark.security.oauth.web.WebOAuthService
import com.tistory.shanepark.dutypark.security.oauth.web.WebOAuthStateException
import com.tistory.shanepark.dutypark.security.service.AuthService
import com.tistory.shanepark.dutypark.security.service.CookieService
import jakarta.validation.Valid
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*
import org.springframework.web.util.UriComponentsBuilder
import java.net.URI

@RestController
@RequestMapping("/api/auth")
class OAuthController(
    private val kakaoLoginService: KakaoLoginService,
    private val naverLoginService: NaverLoginService,
    private val memberService: MemberService,
    private val authService: AuthService,
    private val cookieService: CookieService,
    private val consentService: ConsentService,
    private val policyService: PolicyService,
    private val webOAuthService: WebOAuthService,
) {
    companion object {
        private const val SOCIAL_LINK_ERROR_ALREADY_LINKED = "already_linked"
        private const val WEB_OAUTH_CALLBACK = "/auth/oauth-callback"
        private val INVALID_STATE_URI: URI = URI.create("$WEB_OAUTH_CALLBACK#error=oauth_state_invalid")
    }

    @PostMapping("oauth2/authorize")
    fun authorizeWebOAuth(
        @RequestBody request: WebOAuthAuthorizeRequest,
        httpServletRequest: HttpServletRequest,
        @Login(required = false) loginMember: LoginMember?,
    ): WebOAuthAuthorizeResponse = webOAuthService.authorize(request, loginMember, httpServletRequest)

    @GetMapping("Oauth2ClientCallback/kakao")
    fun kakaoLoginCallback(
        @RequestParam code: String,
        @RequestParam(value = "state") stateString: String,
        httpServletRequest: HttpServletRequest,
        httpServletResponse: HttpServletResponse,
        @Login(required = false) loginMember: LoginMember?
    ): ResponseEntity<Void> {
        val claim = try {
            webOAuthService.claim(SsoType.KAKAO, stateString, loginMember, httpServletRequest)
        } catch (_: WebOAuthStateException) {
            return invalidStateResponse()
        }
        val redirectUrl = webOAuthService.callbackUri(SsoType.KAKAO)
        if (claim.purpose == WebOAuthPurpose.LINK) {
            return try {
                kakaoLoginService.setKakaoIdToMember(
                    code = code,
                    redirectUrl = redirectUrl,
                    loginMember = requireNotNull(loginMember),
                )
                ResponseEntity.status(HttpStatus.FOUND)
                    .location(buildSocialLinkSuccessUri(claim.referer, SsoType.KAKAO))
                    .build()
            } catch (e: SocialAccountAlreadyLinkedException) {
                ResponseEntity.status(HttpStatus.FOUND)
                    .location(buildSocialLinkErrorUri(claim.referer, e.provider))
                    .build()
            }
        }
        return kakaoLoginService.login(
            req = httpServletRequest,
            resp = httpServletResponse,
            code = code,
            redirectUrl = redirectUrl,
            callbackUrl = WEB_OAUTH_CALLBACK,
            redirectTarget = claim.referer,
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
        val claim = try {
            webOAuthService.claim(SsoType.NAVER, stateString, loginMember, httpServletRequest)
        } catch (_: WebOAuthStateException) {
            return invalidStateResponse()
        }
        if (claim.purpose == WebOAuthPurpose.LINK) {
            return try {
                naverLoginService.setNaverIdToMember(
                    code = code,
                    state = stateString,
                    loginMember = requireNotNull(loginMember),
                )
                ResponseEntity.status(HttpStatus.FOUND)
                    .location(buildSocialLinkSuccessUri(claim.referer, SsoType.NAVER))
                    .build()
            } catch (e: SocialAccountAlreadyLinkedException) {
                ResponseEntity.status(HttpStatus.FOUND)
                    .location(buildSocialLinkErrorUri(claim.referer, e.provider))
                    .build()
            }
        }
        return naverLoginService.login(
            req = httpServletRequest,
            resp = httpServletResponse,
            code = code,
            state = stateString,
            callbackUrl = WEB_OAUTH_CALLBACK,
            redirectTarget = claim.referer,
        )
    }

    @PostMapping("sso/signup/token")
    @SlackNotification
    fun ssoSignup(
        @Valid @RequestBody request: SsoSignupRequest,
        httpServletRequest: HttpServletRequest,
        httpServletResponse: HttpServletResponse
    ): ResponseEntity<Map<String, Any>> {
        val currentTermsVersion = policyService.getCurrentPolicy(PolicyType.TERMS)?.version
        if (request.termsVersion != currentTermsVersion) {
            throw BadRequestException("policy.terms.version.outdated")
        }

        val currentPrivacyVersion = policyService.getCurrentPolicy(PolicyType.PRIVACY)?.version
        if (request.privacyVersion != currentPrivacyVersion) {
            throw BadRequestException("policy.privacy.version.outdated")
        }

        val member = memberService.createSsoMember(
            username = request.username,
            memberSsoRegisterUUID = request.uuid
        )

        val ipAddress = httpServletRequest.remoteAddr
        val userAgent = httpServletRequest.getHeader("User-Agent")

        consentService.recordConsent(
            member = member,
            policyType = PolicyType.TERMS,
            consentVersion = request.termsVersion!!,
            ipAddress = ipAddress,
            userAgent = userAgent
        )
        consentService.recordConsent(
            member = member,
            policyType = PolicyType.PRIVACY,
            consentVersion = request.privacyVersion!!,
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

    private fun invalidStateResponse(): ResponseEntity<Void> = ResponseEntity.status(HttpStatus.FOUND)
        .location(INVALID_STATE_URI)
        .build()

    private fun buildSocialLinkErrorUri(referer: String, provider: SsoType): URI {
        return UriComponentsBuilder.fromUriString(referer)
            .replaceQueryParam("socialLinkSuccess")
            .replaceQueryParam("socialLinkError", SOCIAL_LINK_ERROR_ALREADY_LINKED)
            .replaceQueryParam("socialProvider", provider.name.lowercase())
            .build(true)
            .toUri()
    }

    private fun buildSocialLinkSuccessUri(referer: String, provider: SsoType): URI {
        return UriComponentsBuilder.fromUriString(URI.create(referer).toASCIIString())
            .replaceQueryParam("socialLinkError")
            .replaceQueryParam("socialLinkSuccess", true)
            .replaceQueryParam("socialProvider", provider.name.lowercase())
            .build(true)
            .toUri()
    }

}
