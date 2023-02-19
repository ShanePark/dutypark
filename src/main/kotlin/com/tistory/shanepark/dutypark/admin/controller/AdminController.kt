package com.tistory.shanepark.dutypark.admin.controller

import com.tistory.shanepark.dutypark.security.domain.dto.RefreshTokenDto
import com.tistory.shanepark.dutypark.security.service.AuthService
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/admin/api/")
class AdminController(
    private val authService: AuthService
) {
    @GetMapping("/refresh-tokens")
    fun findAllRefreshTokens(): List<RefreshTokenDto> {
        return authService.findAllRefreshTokens()
    }

}
