package com.tistory.shanepark.dutypark.security.config

import com.tistory.shanepark.dutypark.security.domain.enums.TokenStatus
import com.tistory.shanepark.dutypark.security.service.AuthService
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.web.servlet.HandlerInterceptor

class JwtAuthInterceptor(
    private val authService: AuthService
) : HandlerInterceptor {

    val log: org.slf4j.Logger = org.slf4j.LoggerFactory.getLogger(JwtAuthInterceptor::class.java)

    override fun preHandle(request: HttpServletRequest, response: HttpServletResponse, handler: Any): Boolean {
        var sessionCookie = findCookie(request, "SESSION")
        if (sessionCookie != null) {
            var status = authService.validateToken(sessionCookie)
            var jwt: String = sessionCookie

            if (status == TokenStatus.EXPIRED) {
                log.info("Token expired. Trying to refresh token.")
                findCookie(request, "REFRESH")?.let { refreshToken ->
                    authService.refreshToken(refreshToken)?.let { newToken ->
                        jwt = newToken
                    }
                    status = TokenStatus.VALID
                }
            }

            if (status == TokenStatus.VALID) {
                val loginMember = authService.tokenToLoginMember(jwt)
                request.setAttribute("loginMember", loginMember)
            }

            log.info("Token status: $status")

        }
        return true
    }

    private fun findCookie(request: HttpServletRequest, name: String): String? {
        request.cookies?.forEach { cookie ->
            if (cookie.name == name) {
                return cookie.value
            }
        }
        return null
    }
}
