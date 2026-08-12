package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.oauth.mobile.MobileOAuthAuthorizeRequest
import com.tistory.shanepark.dutypark.security.oauth.mobile.MobileOAuthAuthorizeResponse
import com.tistory.shanepark.dutypark.security.oauth.mobile.MobileOAuthExchangeRequest
import com.tistory.shanepark.dutypark.security.oauth.mobile.MobileOAuthExchangeResponse
import com.tistory.shanepark.dutypark.security.oauth.mobile.MobileOAuthService
import com.tistory.shanepark.dutypark.security.service.CookieService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/auth/mobile/oauth")
class MobileOAuthController(
    private val mobileOAuthService: MobileOAuthService,
    private val cookieService: CookieService,
) {
    @PostMapping("/authorize")
    fun authorize(
        @Valid @RequestBody request: MobileOAuthAuthorizeRequest,
        @Login(required = false) loginMember: LoginMember?,
        servletRequest: HttpServletRequest,
    ): MobileOAuthAuthorizeResponse = mobileOAuthService.authorize(
        request = request,
        loginMember = loginMember,
        mobileOAuthBaseUrl = servletRequest.requestURL.toString().removeSuffix("/authorize"),
    )

    @GetMapping("/callback/{provider}")
    fun callback(
        @PathVariable provider: String,
        @RequestParam(required = false) code: String?,
        @RequestParam state: String,
        @RequestParam(required = false) error: String?,
        servletRequest: HttpServletRequest,
    ): ResponseEntity<Void> = ResponseEntity.status(HttpStatus.FOUND)
        .location(
            mobileOAuthService.completeCallback(
                providerName = provider,
                code = code,
                state = state,
                error = error,
                providerRedirectUri = servletRequest.requestURL.toString(),
            )
        )
        .build()

    @PostMapping("/exchange")
    fun exchange(
        @Valid @RequestBody request: MobileOAuthExchangeRequest,
        servletRequest: HttpServletRequest,
        servletResponse: HttpServletResponse,
    ): MobileOAuthExchangeResponse {
        val result = mobileOAuthService.exchange(request, servletRequest)
        if (result.accessToken != null && result.refreshToken != null) {
            cookieService.setTokenCookies(servletResponse, result.accessToken, result.refreshToken)
        }
        return result.response
    }
}
