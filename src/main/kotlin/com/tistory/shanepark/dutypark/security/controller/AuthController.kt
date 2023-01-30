package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.common.exceptions.AuthenticationException
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.service.AuthService
import jakarta.servlet.http.HttpSession
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.web.server.Cookie.SameSite
import org.springframework.http.HttpHeaders
import org.springframework.http.ResponseCookie
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.*

@Controller
class AuthController(
    private val authService: AuthService,
    @Value("\${jwt.token-validity-in-seconds}") val tokenValidityInSeconds: Long,
    @Value("\${jwt.refresh-token-validity-in-days}") val refreshTokenValidDays: Long
) {
    private val log = org.slf4j.LoggerFactory.getLogger(AuthController::class.java)

    @GetMapping("/login")
    fun loginPage(
        @CookieValue(name = "rememberMe", required = false) rememberMe: String?,
        @RequestHeader(HttpHeaders.REFERER, required = false) referer: String?,
        httpSession: HttpSession,
        model: Model
    ): String {
        rememberMe?.let {
            model.addAttribute("rememberMe", rememberMe)
        }
        referer?.let {
            httpSession.setAttribute("referer", referer)
        }
        return "member/login"
    }

    @PostMapping("/login")
    @ResponseBody
    fun login(
        @RequestBody loginDto: LoginDto,
        model: Model,
        @SessionAttribute(name = "referer", required = false) referer: String?
    ): ResponseEntity<String> {
        try {
            val token = authService.login(loginDto)
            val refreshToken = authService.createRefreshToken(loginDto)

            val jwtCookie = ResponseCookie.from("SESSION", token)
                .httpOnly(true)
                .path("/")
                .secure(true)
                .maxAge(tokenValidityInSeconds)
                .sameSite(SameSite.STRICT.name)
                .build()

            val refToken = ResponseCookie.from("REFRESH_TOKEN", refreshToken)
                .httpOnly(true)
                .path("/")
                .secure(true)
                .maxAge(refreshTokenValidDays * 24 * 60 * 60)
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
    @ResponseBody
    fun loginStatus(
        @Login(required = false)
        loginMember: LoginMember?
    ): LoginMember? {
        log.info("Login Member: $loginMember")
        return loginMember
    }

}
