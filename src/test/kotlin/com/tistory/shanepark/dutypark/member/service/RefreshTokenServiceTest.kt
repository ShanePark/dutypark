package com.tistory.shanepark.dutypark.member.service

import ch.qos.logback.classic.Logger
import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.core.read.ListAppender
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
import org.slf4j.LoggerFactory
import java.time.LocalDateTime
import java.util.*


@ExtendWith(MockitoExtension::class)
class RefreshTokenServiceTest {

    private val fixedDateTime = LocalDateTime.of(2025, 1, 15, 12, 0, 0)
    private val chromeUserAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

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
        val member = memberWithId(1L).also { it.name = "Owner Name" }
        val refreshToken = refreshTokenWithId(1L, member)

        whenever(refreshTokenRepository.findById(1L)).thenReturn(Optional.of(refreshToken))

        val loginMember = LoginMember(
            id = 1L,
            email = "",
            name = "Actor Name",
            team = "",
            isAdmin = false,
        )

        val logs = captureRefreshTokenLogs {
            refreshTokenService.deleteRefreshToken(loginMember, 1L)
        }

        verify(refreshTokenRepository).findById(1L)
        verify(refreshTokenRepository).delete(refreshToken)
        assertThat(logs).contains("Actor Name", "\"id\":1", "refreshTokenId", "delete")
            .doesNotContain("Owner Name", member.email ?: "")
    }

    @Test
    fun adminCanDeleteAnyRefreshToken() {
        val member = memberWithId(1L).also { it.name = "Target Member" }
        val refreshToken = refreshTokenWithId(1L, member)

        whenever(refreshTokenRepository.findById(1L)).thenReturn(Optional.of(refreshToken))

        val loginMember = LoginMember(
            id = 2L,
            email = "",
            name = "Admin Actor",
            team = "",
            isAdmin = true,
        )

        val logs = captureRefreshTokenLogs {
            refreshTokenService.deleteRefreshToken(loginMember, 1L)
        }

        verify(refreshTokenRepository).findById(1L)
        verify(refreshTokenRepository).delete(refreshToken)
        assertThat(logs).contains("Admin Actor", "2", "\"id\":1", "admin_revoked_session")
            .doesNotContain("Target Member")
    }

    @Test
    fun deleteRefreshTokenFailIfNotSameUser() {
        val member = memberWithId(1L).also { it.name = "Owner Name" }
        val refreshToken = refreshTokenWithId(1L, member)

        whenever(refreshTokenRepository.findById(1L)).thenReturn(Optional.of(refreshToken))

        val loginMember = LoginMember(
            id = 2L,
            email = "",
            name = "Actor Name",
            team = "",
            isAdmin = false,
        )

        val logs = captureRefreshTokenLogs {
            val exception = assertThrows<AuthException> {
                refreshTokenService.deleteRefreshToken(loginMember, 1L)
            }
            assertThat(exception.message).isEqualTo("auth.refreshToken.delete.forbidden")
        }
        verify(refreshTokenRepository).findById(1L)
        assertThat(logs).contains("Actor Name", "\"id\":1", "2", "1", "not_token_owner")
            .doesNotContain("Owner Name")
    }

    @Test
    fun `Revoke expired refreshTokens Test`() {
        val member = memberWithId(1L)
        val expiredToken1 = refreshTokenWithId(1L, member, validUntil = fixedDateTime.minusDays(1))
        val expiredToken2 = refreshTokenWithId(2L, member, validUntil = fixedDateTime.minusDays(2))
        val expiredTokens = listOf(expiredToken1, expiredToken2)

        whenever(refreshTokenRepository.findAllByValidUntilIsBefore(any())).thenReturn(expiredTokens)

        val logs = captureRefreshTokenLogs {
            refreshTokenService.revokeExpiredRefreshTokens()
        }

        verify(refreshTokenRepository).findAllByValidUntilIsBefore(any())
        verify(refreshTokenRepository).deleteAll(expiredTokens)
        assertThat(logs).contains("system", "expired_revoked", "2", "expired")
            .doesNotContain(expiredToken1.token, expiredToken2.token)
    }

    @Test
    fun `Revoke All refresh Tokens by Member Test`() {
        val member = memberWithId(1L).also { it.name = "Target Name" }
        val tokens = (1..10).map { refreshTokenWithId(it.toLong(), member) }
        val actor = LoginMember(
            id = 99L,
            email = "admin-private@example.com",
            name = "Admin Actor",
            isAdmin = true,
        )

        whenever(refreshTokenRepository.findAllByMember(member)).thenReturn(tokens)

        val logs = captureRefreshTokenLogs {
            refreshTokenService.revokeAllRefreshTokensByMember(member, actor, "account_suspension")
        }

        verify(refreshTokenRepository).findAllByMember(member)
        verify(refreshTokenRepository).deleteAll(tokens)
        assertThat(logs)
            .contains("Admin Actor", "99", "Target Name", "1", "10", "account_suspension")
            .doesNotContain("admin-private@example.com", member.email ?: "", tokens.first().token)
    }

    @Test
    fun `deleting refresh token by cookie logs target identity without token value`() {
        val member = memberWithId(2L).also { it.name = "Logout Target" }
        val refreshToken = refreshTokenWithId(12L, member)
        whenever(refreshTokenRepository.findByToken(refreshToken.token)).thenReturn(refreshToken)

        val logs = captureRefreshTokenLogs {
            assertThat(refreshTokenService.deleteByToken(refreshToken.token)).isTrue()
        }

        verify(refreshTokenRepository).delete(refreshToken)
        assertThat(logs)
            .contains("\"actor\":{\"id\":2,\"name\":\"Logout Target\"}", "Logout Target", "2", "12", "deleted")
            .doesNotContain(refreshToken.token, member.email ?: "")
    }

    @Test
    fun `delete other refresh tokens logs actor and owner without token values`() {
        val member = memberWithId(3L).also { it.name = "Session Owner" }
        val current = refreshTokenWithId(31L, member)
        val other = refreshTokenWithId(32L, member)
        val actor = LoginMember(id = 3L, email = "private@example.com", name = "Session Owner")
        whenever(refreshTokenRepository.findAllByMemberIdOrderByLastUsedDesc(3L)).thenReturn(listOf(current, other))

        val logs = captureRefreshTokenLogs {
            assertThat(refreshTokenService.deleteOtherRefreshTokens(3L, current.token, actor)).isEqualTo(1)
        }

        verify(refreshTokenRepository).deleteAll(listOf(other))
        assertThat(logs)
            .contains("Session Owner", "3", "deleted_other", "1")
            .doesNotContain("private@example.com", current.token, other.token)
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

    @Test
    fun `createRefreshToken stores raw user agent without eager parsing`() {
        val member = memberWithId(1L)
        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        whenever(refreshTokenRepository.save(any<RefreshToken>())).thenAnswer { invocation ->
            val token = invocation.getArgument<RefreshToken>(0)
            refreshTokenWithIdFrom(1L, token)
        }

        val result = refreshTokenService.createRefreshToken(1L, "127.0.0.1", chromeUserAgent)

        assertThat(result.userAgent).isEqualTo(chromeUserAgent)
    }

    @Test
    fun `isSessionActive requires matching member and unexpired token`() {
        whenever(
            refreshTokenRepository.existsByIdAndMemberIdAndValidUntilAfter(
                org.mockito.kotlin.eq(10L),
                org.mockito.kotlin.eq(1L),
                any(),
            )
        ).thenReturn(true)

        assertThat(refreshTokenService.isSessionActive(10L, 1L)).isTrue()
        verify(refreshTokenRepository).existsByIdAndMemberIdAndValidUntilAfter(
            org.mockito.kotlin.eq(10L),
            org.mockito.kotlin.eq(1L),
            any(),
        )
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
        validUntil: LocalDateTime = fixedDateTime.plusDays(30)
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

    private fun captureRefreshTokenLogs(block: () -> Unit): String {
        val logger = LoggerFactory.getLogger(RefreshTokenService::class.java) as Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try {
            block()
        } finally {
            logger.detachAppender(appender)
            appender.stop()
        }
        return appender.list.joinToString("\n") { it.formattedMessage }
    }
}
