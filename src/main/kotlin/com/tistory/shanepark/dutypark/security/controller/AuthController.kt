package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.service.AuthService
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.web.server.Cookie.SameSite
import org.springframework.http.HttpHeaders
import org.springframework.http.ResponseCookie
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*
import java.time.Duration

@RestController
@RequestMapping("/auth/")
class AuthController(
    private val authService: AuthService
) {

    private val log = org.slf4j.LoggerFactory.getLogger(AuthController::class.java)

    @Value("\${dutypark.domain}")
    lateinit var domain: String

    @PostMapping("/login")
    fun login(@RequestBody loginDto: LoginDto): ResponseEntity<Any> {
        val session = authService.authenticate(loginDto)
        val responseCookie = ResponseCookie.from("SESSION", session.accessToken)
            .domain(domain)
            .path("/")
            .secure(true)
            .maxAge(Duration.ofDays(30))
            .sameSite(SameSite.STRICT.name)
            .build()

        log.info("domain: $domain")
        log.info("responseCookie: $responseCookie")

        return ResponseEntity.ok()
            .header(HttpHeaders.SET_COOKIE, responseCookie.toString())
            .build()
    }

    @GetMapping("/check")
    fun check(): String {
        return "OK"
    }

}
