package com.tistory.shanepark.dutypark.security.handlers

import com.tistory.shanepark.dutypark.security.repository.RefreshTokenRepository
import jakarta.servlet.http.Cookie
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.springframework.security.core.Authentication
import org.springframework.security.web.authentication.logout.LogoutSuccessHandler
import org.springframework.stereotype.Component

@Component
class LogoutSuccessHandle(
    private val refreshTokenRepository: RefreshTokenRepository,
) : LogoutSuccessHandler {
    val log: Logger = LoggerFactory.getLogger(LogoutSuccessHandle::class.java)

    override fun onLogoutSuccess(
        request: HttpServletRequest,
        response: HttpServletResponse,
        authentication: Authentication?
    ) {
        request.cookies?.firstOrNull { it.name == "REFRESH_TOKEN" }?.value
            ?.let {
                refreshTokenRepository.findByToken(it)?.let { refreshToken ->
                    refreshTokenRepository.delete(refreshToken);
                }
            }

        response.addCookie(Cookie("SESSION", "").apply {
            maxAge = 0
            path = "/"
            isHttpOnly = true
        })
        response.addCookie(Cookie("REFRESH_TOKEN", "").apply {
            maxAge = 0
            path = "/"
            isHttpOnly = true
        })

        response.sendRedirect(request.getHeader("Referer"))
    }
}
