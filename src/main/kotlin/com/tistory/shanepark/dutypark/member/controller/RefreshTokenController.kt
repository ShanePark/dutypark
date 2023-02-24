package com.tistory.shanepark.dutypark.member.controller

import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.RefreshTokenDto
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/refresh-tokens")
class RefreshTokenController(
    private val refreshTokenService: RefreshTokenService
) {

    @GetMapping
    fun findAllRefreshTokens(
        @Login loginMember: LoginMember,
        @CookieValue("REFRESH_TOKEN", required = false) currentToken: String?
    ): List<RefreshTokenDto> {
        val refreshTokens = refreshTokenService.findAllRefreshTokensByMember(loginMember.id)
        refreshTokens
            .firstOrNull { it.token == currentToken }
            ?.isCurrentLogin = true
        return refreshTokens
    }

    @DeleteMapping("/{id}")
    fun deleteRefreshToken(
        @Login loginMember: LoginMember,
        @PathVariable id: Long,
    ): ResponseEntity<Void> {
        refreshTokenService.deleteRefreshToken(loginMember, id)
        return ResponseEntity.noContent().build()
    }

}
