package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.common.exceptions.AuthenticationException
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.service.AuthService
import jakarta.servlet.http.HttpServletRequest
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.web.server.Cookie.SameSite
import org.springframework.http.HttpHeaders
import org.springframework.http.ResponseCookie
import org.springframework.http.ResponseEntity
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.*

@RestController
class AuthController(
    private val authService: AuthService,
    private val jwtConfig: JwtConfig,
    @Value("\${server.ssl.enabled}") private val isSecure: Boolean
) {
    private val log = org.slf4j.LoggerFactory.getLogger(AuthController::class.java)

    @PostMapping("/login")
    fun login(
        @RequestBody loginDto: LoginDto,
        model: Model,
        req: HttpServletRequest,
        @SessionAttribute(name = "referer", required = false) referer: String?
    ): ResponseEntity<String> {
        try {
            val token = authService.login(loginDto)
            val refreshToken =
                authService.createRefreshToken(loginDto = loginDto, request = req)

            val jwtCookie = ResponseCookie.from("SESSION", token)
                .httpOnly(true)
                .path("/")
                .secure(true)
                .maxAge(jwtConfig.tokenValidityInSeconds)
                .sameSite(SameSite.STRICT.name)
                .build()

            val refToken = ResponseCookie.from("REFRESH_TOKEN", refreshToken)
                .httpOnly(true)
                .path("/")
                .secure(isSecure)
                .maxAge(jwtConfig.refreshTokenValidityInDays * 24 * 60 * 60)
                .sameSite(SameSite.STRICT.name)
                .build()

            val rememberMeCookieAge = if (loginDto.rememberMe) 3600 * 24 * 365L else 0L
            val rememberMeCookie = ResponseCookie
                .from("rememberMe", if (loginDto.rememberMe) loginDto.email else "")
                .httpOnly(true)
                .path("/")
                .maxAge(rememberMeCookieAge)
                .sameSite(SameSite.STRICT.name)
                .build()

            log.info("Login Success: ${loginDto.email}")

            val responseEntity = ResponseEntity.ok()
                .header(HttpHeaders.SET_COOKIE, jwtCookie.toString())
                .header(HttpHeaders.SET_COOKIE, refToken.toString())
                .header(HttpHeaders.SET_COOKIE, rememberMeCookie.toString())
                .body(referer?.let {
                    if (it.contains("login")) {
                        "/"
                    } else {
                        it
                    }
                })
            return responseEntity

        } catch (e: AuthenticationException) {
            return ResponseEntity.status(401).body(e.message)
        }
    }

    @GetMapping("/status")
    fun loginStatus(
        @Login(required = false)
        loginMember: LoginMember?
    ): LoginMember? {
        log.info("Login Member: $loginMember")
        return loginMember
    }

}
