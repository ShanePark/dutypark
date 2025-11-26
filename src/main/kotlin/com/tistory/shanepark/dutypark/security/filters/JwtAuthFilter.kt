package com.tistory.shanepark.dutypark.security.filters

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.enums.TokenStatus.NOT_EXIST
import com.tistory.shanepark.dutypark.security.domain.enums.TokenStatus.VALID
import com.tistory.shanepark.dutypark.security.service.AuthService
import com.tistory.shanepark.dutypark.security.service.CookieService
import jakarta.servlet.Filter
import jakarta.servlet.FilterChain
import jakarta.servlet.ServletRequest
import jakarta.servlet.ServletResponse
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.http.HttpHeaders
import org.springframework.util.AntPathMatcher

class JwtAuthFilter(
    private val authService: AuthService,
    private val cookieService: CookieService,
) : Filter {
    private val log = logger()
    private val antPathMatcher = AntPathMatcher()

    override fun doFilter(req: ServletRequest, resp: ServletResponse, chain: FilterChain) {

        val request = req as HttpServletRequest
        val response = resp as HttpServletResponse

        if (shouldSkipTheFilter(req))
            return chain.doFilter(req, response)

        var jwt = ""
        var status = NOT_EXIST

        // Try Bearer token first, then fall back to cookie
        val token = extractBearerToken(request) ?: cookieService.extractAccessToken(request.cookies)
        token?.let {
            status = authService.validateToken(it)
            jwt = it
        }

        if (status == VALID) {
            val loginMember = authService.tokenToLoginMember(jwt)
            request.setAttribute(LoginMember.ATTR_NAME, loginMember)
        } else if (status != NOT_EXIST) {
            log.info("Token is invalid. status: $status")
        }

        chain.doFilter(req, response)
    }

    private val skipPatterns = listOf(
        "/css/**",
        "/js/**",
        "/fonts/**",
        "/lib/**",
        "/favicon**",
        "/*.ico",
        "/error",
        "/login",
        "/android-chrome-**"
    )

    private fun shouldSkipTheFilter(request: HttpServletRequest): Boolean {
        val path = request.requestURI
        return skipPatterns.any { pattern -> antPathMatcher.match(pattern, path) }
    }

    private fun extractBearerToken(request: HttpServletRequest): String? {
        val authHeader = request.getHeader(HttpHeaders.AUTHORIZATION) ?: return null
        return if (authHeader.startsWith(BEARER_PREFIX, ignoreCase = true)) {
            authHeader.substring(BEARER_PREFIX.length).trim()
        } else null
    }

    companion object {
        private const val BEARER_PREFIX = "Bearer "
    }
}
