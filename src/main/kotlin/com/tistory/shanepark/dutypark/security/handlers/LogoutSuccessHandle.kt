package com.tistory.shanepark.dutypark.security.handlers

import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import jakarta.servlet.http.Cookie
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.security.core.Authentication
import org.springframework.security.web.authentication.logout.LogoutSuccessHandler
import org.springframework.stereotype.Component

@Component
class LogoutSuccessHandle(
    private val refreshTokenRepository: RefreshTokenRepository,
    private val jwtConfig: JwtConfig,
) : LogoutSuccessHandler {
    override fun onLogoutSuccess(
        request: HttpServletRequest,
        response: HttpServletResponse,
        authentication: Authentication?
    ) {
        request.cookies?.firstOrNull { it.name == RefreshToken.cookieName }?.value
            ?.let {
                refreshTokenRepository.findByToken(it)?.let { refreshToken ->
                    refreshTokenRepository.delete(refreshToken);
                    removeRefreshTokenCookie(response)
                }
            }
        removeJwtCookie(response)
        response.sendRedirect(request.getHeader("Referer"))
    }

    private fun removeRefreshTokenCookie(response: HttpServletResponse) {
        response.addCookie(Cookie(RefreshToken.cookieName, "").apply {
            maxAge = 0
            path = "/"
            isHttpOnly = true
        })
    }

    private fun removeJwtCookie(response: HttpServletResponse) {
        response.addCookie(Cookie(jwtConfig.cookieName, "").apply {
            maxAge = 0
            path = "/"
            isHttpOnly = true
        })
    }
}
