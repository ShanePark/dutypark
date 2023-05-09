package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import com.tistory.shanepark.dutypark.security.service.AuthService
import jakarta.servlet.http.HttpServletRequest
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.HttpHeaders
import org.springframework.http.ResponseCookie
import org.springframework.http.ResponseEntity
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.*

@RestController
class AuthController(
    private val authService: AuthService,
    private val refreshTokenService: RefreshTokenService,
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
            val loginMember = authService.login(loginDto)
            val refreshToken = refreshTokenService.createRefreshToken(
                memberId = loginMember.id,
                remoteAddr = req.remoteAddr,
                userAgent = req.getHeader(HttpHeaders.USER_AGENT)
            )

            val jwtCookie = ResponseCookie.from("SESSION", loginMember.jwt)
                .httpOnly(true)
                .path("/")
                .secure(isSecure)
                .maxAge(jwtConfig.tokenValidityInSeconds)
                .build()

            val refToken = ResponseCookie.from(RefreshToken.cookieName, refreshToken.token)
                .httpOnly(true)
                .path("/")
                .secure(isSecure)
                .maxAge(jwtConfig.refreshTokenValidityInDays * 24 * 60 * 60)
                .build()

            val rememberMeCookieAge = if (loginDto.rememberMe) 3600 * 24 * 365L else 0L
            val rememberMeCookie = ResponseCookie
                .from("rememberMe", if (loginDto.rememberMe) loginDto.email else "")
                .httpOnly(true)
                .path("/")
                .maxAge(rememberMeCookieAge)
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

        } catch (e: DutyparkAuthException) {
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
