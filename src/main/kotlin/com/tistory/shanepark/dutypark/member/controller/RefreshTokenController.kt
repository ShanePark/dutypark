package com.tistory.shanepark.dutypark.member.controller

import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.RefreshTokenDto
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
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
        @CookieValue(value = RefreshToken.cookieName, required = false) currentToken: String?,
        @RequestParam("validOnly", required = false, defaultValue = "true") validOnly: Boolean,
    ): List<RefreshTokenDto> {
        val refreshTokens = refreshTokenService.findRefreshTokens(loginMember.id, validOnly)

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
