package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.oauth.apple.AppleWebExchangeRequest
import com.tistory.shanepark.dutypark.security.oauth.apple.AppleWebOAuthService
import com.tistory.shanepark.dutypark.security.oauth.mobile.MobileOAuthExchangeResponse
import com.tistory.shanepark.dutypark.security.service.CookieService
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import jakarta.validation.Valid
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/auth/web/oauth/apple")
class WebAppleOAuthController(
    private val appleWebOAuthService: AppleWebOAuthService,
    private val cookieService: CookieService,
) {
    @PostMapping("/exchange")
    fun exchange(
        @Valid @RequestBody request: AppleWebExchangeRequest,
        @Login(required = false) loginMember: LoginMember?,
        servletRequest: HttpServletRequest,
        servletResponse: HttpServletResponse,
    ): MobileOAuthExchangeResponse {
        val result = appleWebOAuthService.exchange(request, loginMember, servletRequest)
        if (result.accessToken != null && result.refreshToken != null) {
            cookieService.setTokenCookies(servletResponse, result.accessToken, result.refreshToken)
        }
        return result.response
    }
}
