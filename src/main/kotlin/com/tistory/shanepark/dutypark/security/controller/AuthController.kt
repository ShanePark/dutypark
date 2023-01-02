package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginSessionResponse
import com.tistory.shanepark.dutypark.security.service.AuthService
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/auth/")
class AuthController(
    private val authService: AuthService
) {

    private val log = org.slf4j.LoggerFactory.getLogger(AuthController::class.java)

    @PostMapping("/login")
    fun login(@RequestBody loginDto: LoginDto): LoginSessionResponse {
        val session = authService.authenticate(loginDto)
        return LoginSessionResponse(session.accessToken)
    }

    @GetMapping("/check")
    fun check(): String {
        return "OK"
    }

}