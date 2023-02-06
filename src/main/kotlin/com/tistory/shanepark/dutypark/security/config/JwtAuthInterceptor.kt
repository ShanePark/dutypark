package com.tistory.shanepark.dutypark.security.config

import com.tistory.shanepark.dutypark.security.domain.enums.TokenStatus.*
import com.tistory.shanepark.dutypark.security.service.AuthService
import jakarta.servlet.http.Cookie
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.Logger
import org.springframework.beans.factory.annotation.Value
import org.springframework.web.servlet.HandlerInterceptor

class JwtAuthInterceptor(
    private val authService: AuthService,
    @Value("\${jwt.token-validity-in-seconds}") private val tokenValidityInSeconds: Int
) : HandlerInterceptor {
    private val log: Logger = org.slf4j.LoggerFactory.getLogger(JwtAuthInterceptor::class.java)

    override fun preHandle(request: HttpServletRequest, response: HttpServletResponse, handler: Any): Boolean {
        var jwt = ""
        var status = NOT_EXIST
        val refreshToken = findCookie(request, "REFRESH_TOKEN")
        findCookie(request, "SESSION")?.let {
            status = authService.validateToken(it)
            jwt = it
        }

        if (refreshToken != null && status != VALID) {
            log.info("Token is expired. Trying to refresh token.")
            authService.tokenRefresh(refreshToken)?.let { newToken ->
                jwt = newToken
                addSessionCookie(jwt, response)
                status = VALID
            } ?: run {
                log.info("Refresh token is expired or invalid.")
                removeCookie("REFRESH_TOKEN", response)
            }
        }

        if (status == VALID) {
            val loginMember = authService.tokenToLoginMember(jwt)
            request.setAttribute("loginMember", loginMember)
        } else if (status != NOT_EXIST) { // remove invalid token
            log.info("Token is invalid. Removing the tokens. status: $status, jwt: $jwt")
            removeCookie("SESSION", response)
        }
        return true
    }

    private fun removeCookie(name: String, response: HttpServletResponse) {
        val cookie = Cookie(name, "")
            .apply {
                path = "/"
                maxAge = 0
            }
        response.addCookie(cookie)
    }

    private fun addSessionCookie(jwt: String, response: HttpServletResponse) {
        val cookie = Cookie("SESSION", jwt)
            .apply {
                path = "/"
                maxAge = tokenValidityInSeconds
            }
        response.addCookie(cookie)
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
