package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.security.config.CookieConfig
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import jakarta.servlet.http.Cookie
import jakarta.servlet.http.HttpServletResponse
import org.springframework.http.HttpHeaders
import org.springframework.http.ResponseCookie
import org.springframework.stereotype.Service

@Service
class CookieService(
    private val cookieConfig: CookieConfig,
    private val jwtConfig: JwtConfig,
) {
    companion object {
        const val ACCESS_TOKEN_COOKIE = "access_token"
        const val REFRESH_TOKEN_COOKIE = "refresh_token"
    }

    fun setAccessTokenCookie(response: HttpServletResponse, accessToken: String) {
        val cookie = ResponseCookie.from(ACCESS_TOKEN_COOKIE, accessToken)
            .httpOnly(true)
            .secure(cookieConfig.secure)
            .sameSite(cookieConfig.sameSite)
            .path("/")
            .maxAge(jwtConfig.tokenValidityInSeconds)
            .apply { cookieConfig.domain?.let { domain(it) } }
            .build()

        response.addHeader(HttpHeaders.SET_COOKIE, cookie.toString())
    }

    fun setRefreshTokenCookie(response: HttpServletResponse, refreshToken: String) {
        val cookie = ResponseCookie.from(REFRESH_TOKEN_COOKIE, refreshToken)
            .httpOnly(true)
            .secure(cookieConfig.secure)
            .sameSite(cookieConfig.sameSite)
            .path("/api/auth")
            .maxAge(jwtConfig.refreshTokenValidityInDays * 24 * 60 * 60)
            .apply { cookieConfig.domain?.let { domain(it) } }
            .build()

        response.addHeader(HttpHeaders.SET_COOKIE, cookie.toString())
    }

    fun setTokenCookies(response: HttpServletResponse, accessToken: String, refreshToken: String) {
        setAccessTokenCookie(response, accessToken)
        setRefreshTokenCookie(response, refreshToken)
    }

    fun clearTokenCookies(response: HttpServletResponse) {
        val accessCookie = ResponseCookie.from(ACCESS_TOKEN_COOKIE, "")
            .httpOnly(true)
            .secure(cookieConfig.secure)
            .sameSite(cookieConfig.sameSite)
            .path("/")
            .maxAge(0)
            .apply { cookieConfig.domain?.let { domain(it) } }
            .build()

        val refreshCookie = ResponseCookie.from(REFRESH_TOKEN_COOKIE, "")
            .httpOnly(true)
            .secure(cookieConfig.secure)
            .sameSite(cookieConfig.sameSite)
            .path("/api/auth")
            .maxAge(0)
            .apply { cookieConfig.domain?.let { domain(it) } }
            .build()

        response.addHeader(HttpHeaders.SET_COOKIE, accessCookie.toString())
        response.addHeader(HttpHeaders.SET_COOKIE, refreshCookie.toString())
    }

    fun extractAccessToken(cookies: Array<Cookie>?): String? {
        return cookies?.find { it.name == ACCESS_TOKEN_COOKIE }?.value
    }

    fun extractRefreshToken(cookies: Array<Cookie>?): String? {
        return cookies?.find { it.name == REFRESH_TOKEN_COOKIE }?.value
    }
}
