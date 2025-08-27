package com.tistory.shanepark.dutypark.security.filters

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import com.tistory.shanepark.dutypark.security.domain.enums.TokenStatus.NOT_EXIST
import com.tistory.shanepark.dutypark.security.domain.enums.TokenStatus.VALID
import com.tistory.shanepark.dutypark.security.service.AuthService
import jakarta.servlet.Filter
import jakarta.servlet.FilterChain
import jakarta.servlet.ServletRequest
import jakarta.servlet.ServletResponse
import jakarta.servlet.http.Cookie
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.http.HttpHeaders
import org.springframework.http.ResponseCookie
import org.springframework.security.web.util.matcher.AntPathRequestMatcher

class JwtAuthFilter(
    private val authService: AuthService,
    private val jwtConfig: JwtConfig,
    private val isSecure: Boolean
) : Filter {
    private val log = logger()

    override fun doFilter(req: ServletRequest, resp: ServletResponse, chain: FilterChain) {

        val request = req as HttpServletRequest
        val response = resp as HttpServletResponse

        if (shouldSkipTheFilter(req))
            return chain.doFilter(req, response)

        var jwt = ""
        var status = NOT_EXIST
        val refreshToken = findCookie(request, RefreshToken.cookieName)
        findCookie(request, jwtConfig.cookieName)?.let {
            status = authService.validateToken(it)
            jwt = it
        }

        if (refreshToken != null && status != VALID) {
            log.info("Token is expired. Trying to refresh token.")
            authService.tokenRefresh(refreshToken, request, response)?.let { newToken ->
                jwt = newToken
                addSessionCookie(jwt, response)
                status = VALID
            } ?: run {
                log.info("Refresh token is expired or invalid.")
                removeCookie(RefreshToken.cookieName, response)
            }
        }

        if (status == VALID) {
            val loginMember = authService.tokenToLoginMember(jwt)
            request.setAttribute(LoginMember.ATTR_NAME, loginMember)
        } else if (status != NOT_EXIST) { // remove invalid token
            log.info("Token is invalid. Removing the tokens. status: $status, jwt: $jwt")
            removeCookie(jwtConfig.cookieName, response)
        }

        chain.doFilter(req, response)
    }

    private val skipMatchers = listOf(
        AntPathRequestMatcher("/css/**"),
        AntPathRequestMatcher("/js/**"),
        AntPathRequestMatcher("/fonts/**"),
        AntPathRequestMatcher("/lib/**"),
        AntPathRequestMatcher("/favicon**"),
        AntPathRequestMatcher("/*.ico"),
        AntPathRequestMatcher("/error"),
        AntPathRequestMatcher("/login"),
        AntPathRequestMatcher("/android-chrome-**")
    )

    private fun shouldSkipTheFilter(request: HttpServletRequest): Boolean {
        return skipMatchers.any { matcher -> matcher.matches(request) }
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
        val sessionCookie = ResponseCookie.from(jwtConfig.cookieName, jwt)
            .httpOnly(true)
            .path("/")
            .secure(isSecure)
            .maxAge(jwtConfig.tokenValidityInSeconds)
            .build()
        response.addHeader(HttpHeaders.SET_COOKIE, sessionCookie.toString())
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

