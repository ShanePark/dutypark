package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.any
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import java.time.LocalDateTime
import java.util.*


@ExtendWith(MockitoExtension::class)
class RefreshTokenServiceTest {

    @Mock
    private lateinit var memberRepository: MemberRepository

    @Mock
    private lateinit var refreshTokenRepository: RefreshTokenRepository

    private val jwtConfig = JwtConfig(
        secret = "test-secret",
        tokenValidityInSeconds = 3600,
        refreshTokenValidityInDays = 30
    )

    private lateinit var refreshTokenService: RefreshTokenService

    @BeforeEach
    fun setUp() {
        refreshTokenService = RefreshTokenService(
            memberRepository = memberRepository,
            refreshTokenRepository = refreshTokenRepository,
            jwtConfig = jwtConfig
        )
    }

    @Test
    fun deleteRefreshTokenSuccess() {
        val member = memberWithId(1L)
        val refreshToken = refreshTokenWithId(1L, member)

        whenever(refreshTokenRepository.findById(1L)).thenReturn(Optional.of(refreshToken))

        val loginMember = LoginMember(
            id = 1L,
            email = "",
            name = "",
            team = "",
            isAdmin = false,
        )

        refreshTokenService.deleteRefreshToken(loginMember, 1L)

        verify(refreshTokenRepository).delete(refreshToken)
    }

    @Test
    fun adminCanDeleteAnyRefreshToken() {
        val member = memberWithId(1L)
        val refreshToken = refreshTokenWithId(1L, member)

        whenever(refreshTokenRepository.findById(1L)).thenReturn(Optional.of(refreshToken))

        val loginMember = LoginMember(
            id = 2L,
            email = "",
            name = "",
            team = "",
            isAdmin = true,
        )

        refreshTokenService.deleteRefreshToken(loginMember, 1L)

        verify(refreshTokenRepository).delete(refreshToken)
    }

    @Test
    fun deleteRefreshTokenFailIfNotSameUser() {
        val member = memberWithId(1L)
        val refreshToken = refreshTokenWithId(1L, member)

        whenever(refreshTokenRepository.findById(1L)).thenReturn(Optional.of(refreshToken))

        val loginMember = LoginMember(
            id = 2L,
            email = "",
            name = "",
            team = "",
            isAdmin = false,
        )

        assertThrows<AuthException> {
            refreshTokenService.deleteRefreshToken(loginMember, 1L)
        }
    }

    @Test
    fun `Revoke expired refreshTokens Test`() {
        val member = memberWithId(1L)
        val expiredToken1 = refreshTokenWithId(1L, member, validUntil = LocalDateTime.now().minusDays(1))
        val expiredToken2 = refreshTokenWithId(2L, member, validUntil = LocalDateTime.now().minusDays(2))
        val expiredTokens = listOf(expiredToken1, expiredToken2)

        whenever(refreshTokenRepository.findAllByValidUntilIsBefore(any())).thenReturn(expiredTokens)

        refreshTokenService.revokeExpiredRefreshTokens()

        verify(refreshTokenRepository).findAllByValidUntilIsBefore(any())
        verify(refreshTokenRepository).deleteAll(expiredTokens)
    }

    @Test
    fun `Revoke All refresh Tokens by Member Test`() {
        val member = memberWithId(1L)
        val tokens = (1..10).map { refreshTokenWithId(it.toLong(), member) }

        whenever(refreshTokenRepository.findAllByMember(member)).thenReturn(tokens)

        refreshTokenService.revokeAllRefreshTokensByMember(member)

        verify(refreshTokenRepository).findAllByMember(member)
        verify(refreshTokenRepository).deleteAll(tokens)
    }

    @Test
    fun `createRefreshToken creates token for member`() {
        val member = memberWithId(1L)
        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        whenever(refreshTokenRepository.save(any<RefreshToken>())).thenAnswer { invocation ->
            val token = invocation.getArgument<RefreshToken>(0)
            refreshTokenWithIdFrom(1L, token)
        }

        val result = refreshTokenService.createRefreshToken(1L, "127.0.0.1", "TestAgent")

        assertThat(result.member).isEqualTo(member)
        assertThat(result.remoteAddr).isEqualTo("127.0.0.1")
        verify(memberRepository).findById(1L)
        verify(refreshTokenRepository).save(any<RefreshToken>())
    }

    private fun memberWithId(id: Long): Member {
        val member = Member("user$id", "user$id@duty.park", "pass")
        val field = Member::class.java.getDeclaredField("id")
        field.isAccessible = true
        field.set(member, id)
        return member
    }

    private fun refreshTokenWithId(
        id: Long,
        member: Member,
        validUntil: LocalDateTime = LocalDateTime.now().plusDays(30)
    ): RefreshToken {
        val refreshToken = RefreshToken(
            member = member,
            validUntil = validUntil,
            remoteAddr = "127.0.0.1",
            userAgent = null
        )
        val field = RefreshToken::class.java.getDeclaredField("id")
        field.isAccessible = true
        field.set(refreshToken, id)
        return refreshToken
    }

    private fun refreshTokenWithIdFrom(id: Long, source: RefreshToken): RefreshToken {
        val field = RefreshToken::class.java.getDeclaredField("id")
        field.isAccessible = true
        field.set(source, id)
        return source
    }
}
