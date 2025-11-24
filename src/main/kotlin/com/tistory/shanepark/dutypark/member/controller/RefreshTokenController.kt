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
        @CookieValue(value = RefreshToken.cookieName, required = false) cookieToken: String?,
        @RequestHeader("X-Current-Token", required = false) headerToken: String?,
        @RequestParam("validOnly", required = false, defaultValue = "true") validOnly: Boolean,
    ): List<RefreshTokenDto> {
        val refreshTokens = refreshTokenService.findRefreshTokens(loginMember.id, validOnly)

        // SPA uses header token, legacy uses cookie token
        val currentToken = headerToken ?: cookieToken
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

    /**
     * Delete current refresh token (for SPA logout)
     */
    @DeleteMapping("/current")
    fun deleteCurrentRefreshToken(
        @RequestHeader("X-Current-Token", required = false) headerToken: String?,
        @CookieValue(value = RefreshToken.cookieName, required = false) cookieToken: String?,
    ): ResponseEntity<Void> {
        val token = headerToken ?: cookieToken
        if (token != null) {
            refreshTokenService.deleteByToken(token)
        }
        return ResponseEntity.noContent().build()
    }

}
