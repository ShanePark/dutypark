package com.tistory.shanepark.dutypark.admin.controller

import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.security.domain.dto.RefreshTokenDto
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/admin/api/")
class AdminController(
    private val refreshTokenService: RefreshTokenService
) {
    @GetMapping("/refresh-tokens")
    fun findAllRefreshTokens(): List<RefreshTokenDto> {
        return refreshTokenService.findAllWithMemberOrderByLastUsedDesc()
    }

}
