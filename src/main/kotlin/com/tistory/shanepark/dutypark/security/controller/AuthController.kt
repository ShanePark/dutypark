package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.service.AuthService
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.web.server.Cookie.SameSite
import org.springframework.http.HttpHeaders
import org.springframework.http.ResponseCookie
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/auth/")
class AuthController(
    private val authService: AuthService,
    @param:Value("\${dutypark.domain}")
    private val domain: String,
    @Value("\${jwt.token-validity-in-seconds}") val tokenValidityInSeconds: Long,
    @Value("\${jwt.refresh-token-validity-in-days}") val refreshTokenValidDays: Long
) {

    private val log = org.slf4j.LoggerFactory.getLogger(AuthController::class.java)

    @PostMapping("/login")
    fun login(@RequestBody loginDto: LoginDto): ResponseEntity<String> {
        val token = authService.login(loginDto)
        val refreshToken = authService.createRefreshToken(loginDto)
        val jwtCookie = ResponseCookie.from("SESSION", token)
            .domain(domain)
            .httpOnly(true)
            .path("/")
            .secure(true)
            .maxAge(tokenValidityInSeconds)
            .sameSite(SameSite.STRICT.name)
            .build()
        val refToken = ResponseCookie.from("REFRESH_TOKEN", refreshToken)
            .domain(domain)
            .httpOnly(true)
            .path("/")
            .secure(true)
            .maxAge(refreshTokenValidDays * 24 * 60 * 60)
            .sameSite(SameSite.STRICT.name)
            .build()

        return ResponseEntity.ok()
            .header(HttpHeaders.SET_COOKIE, jwtCookie.toString())
            .header(HttpHeaders.SET_COOKIE, refToken.toString())
            .build()
    }

    @GetMapping("/status")
    fun loginStatus(loginMember: LoginMember): LoginMember {
        return loginMember
    }

}
