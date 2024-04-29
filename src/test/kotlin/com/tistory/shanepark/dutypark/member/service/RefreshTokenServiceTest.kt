package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest

import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.beans.factory.annotation.Autowired
import java.time.LocalDateTime


class RefreshTokenServiceTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var refreshTokenService: RefreshTokenService

    @Autowired
    lateinit var refreshTokenRepository: RefreshTokenRepository

    @Test
    fun deleteRefreshTokenSuccess() {
        val member = TestData.member
        val token = refreshTokenService.createRefreshToken(memberId = member.id!!, null, null)
        assertThat(refreshTokenService.findAllWithMemberOrderByLastUsedDesc()).hasSize(1)

        val loginMember = LoginMember(
            id = member.id!!,
            email = "",
            name = "",
            departmentId = null,
            department = "",
            isAdmin = false,
        )
        refreshTokenService.deleteRefreshToken(loginMember, token.id!!)
        assertThat(refreshTokenService.findAllWithMemberOrderByLastUsedDesc()).isEmpty()
    }

    @Test
    fun adminCanDeleteAnyRefreshToken() {
        val member = TestData.member
        val token = refreshTokenService.createRefreshToken(memberId = member.id!!, null, null)
        assertThat(refreshTokenService.findAllWithMemberOrderByLastUsedDesc()).hasSize(1)

        val loginMember = LoginMember(
            id = member.id!! + 1,
            email = "",
            name = "",
            departmentId = null,
            department = "",
            isAdmin = true,
        )
        refreshTokenService.deleteRefreshToken(loginMember, token.id!!)
        assertThat(refreshTokenService.findAllWithMemberOrderByLastUsedDesc()).isEmpty()
    }

    @Test
    fun deleteRefreshTokenFailIfNotSameUser() {
        val member = TestData.member
        val token = refreshTokenService.createRefreshToken(memberId = member.id!!, null, null)
        assertThat(refreshTokenService.findAllWithMemberOrderByLastUsedDesc()).hasSize(1)
        val loginMember = LoginMember(
            id = member.id!! + 1,
            email = "",
            name = "",
            departmentId = null,
            department = "",
            isAdmin = false,
        )

        assertThrows<DutyparkAuthException> {
            refreshTokenService.deleteRefreshToken(loginMember, token.id!!)
        }
    }

    @Test
    fun `Revoke expired refreshTokens Test`() {
        // Given
        assertThat(refreshTokenService.findAllWithMemberOrderByLastUsedDesc()).isEmpty()
        val member = TestData.member
        val token1 = refreshTokenService.createRefreshToken(memberId = member.id!!, null, null)
        val token2 = refreshTokenService.createRefreshToken(memberId = member.id!!, null, null)
        val token3 = refreshTokenService.createRefreshToken(memberId = member.id!!, null, null)
        assertThat(refreshTokenService.findAllWithMemberOrderByLastUsedDesc()).hasSize(3)

        // Then
        refreshTokenService.revokeExpiredRefreshTokens()
        assertThat(refreshTokenService.findAllWithMemberOrderByLastUsedDesc()).hasSize(3)

        invalidateToken(token1)
        refreshTokenService.revokeExpiredRefreshTokens()
        assertThat(refreshTokenService.findAllWithMemberOrderByLastUsedDesc()).hasSize(2)

        invalidateToken(token2)
        invalidateToken(token3)
        refreshTokenService.revokeExpiredRefreshTokens()
        assertThat(refreshTokenService.findAllWithMemberOrderByLastUsedDesc()).isEmpty()
    }

    private fun invalidateToken(token: RefreshToken) {
        token.validUntil = LocalDateTime.now().minusDays(1)
        refreshTokenRepository.save(token)
    }

    @Test
    fun `Revoke All refresh Tokens by Member Test`() {
        // Given
        assertThat(refreshTokenService.findAllWithMemberOrderByLastUsedDesc()).isEmpty()
        val member = TestData.member
        val refeshTokenCount = 10
        for (i in 1..refeshTokenCount) {
            refreshTokenService.createRefreshToken(memberId = member.id!!, null, null)
        }
        assertThat(refreshTokenService.findAllWithMemberOrderByLastUsedDesc()).hasSize(refeshTokenCount)

        // Then
        refreshTokenService.revokeAllRefreshTokensByMember(member)
        assertThat(refreshTokenService.findAllWithMemberOrderByLastUsedDesc()).isEmpty()
    }

}
