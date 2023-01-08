package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
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
    @Value("\${jwt.token-validity-in-seconds}") val tokenValidityInSeconds: Long
) {

    private val log = org.slf4j.LoggerFactory.getLogger(AuthController::class.java)

    @PostMapping("/login")
    fun login(@RequestBody loginDto: LoginDto): ResponseEntity<String> {
        val token = authService.authenticate(loginDto)
        val cookie = ResponseCookie.from("SESSION", token)
            .domain(domain)
            .httpOnly(true)
            .path("/")
            .secure(true)
            .maxAge(tokenValidityInSeconds)
            .sameSite(SameSite.STRICT.name)
            .build()

        return ResponseEntity.ok()
            .header(HttpHeaders.SET_COOKIE, cookie.toString())
            .build()
    }

    @GetMapping("/check")
    fun check(): String {
        return "OK"
    }

}
