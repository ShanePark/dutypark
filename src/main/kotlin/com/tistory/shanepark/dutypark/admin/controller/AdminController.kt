package com.tistory.shanepark.dutypark.admin.controller

import com.tistory.shanepark.dutypark.security.service.AuthService
import org.springframework.web.bind.annotation.RestController

@RestController
class AdminController(
    private val authService: AuthService
) {

    // TODO
    fun findRefreshTokens() {
        val refreshTokens = authService.findAllRefreshTokens()
    }

}
