package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.common.exceptions.RateLimitException
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberManager
import com.tistory.shanepark.dutypark.member.domain.enums.ManagerRole
import com.tistory.shanepark.dutypark.member.repository.MemberManagerRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.PasswordChangeDto
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import com.tistory.shanepark.dutypark.security.domain.enums.TokenStatus
import jakarta.persistence.EntityManager
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mockito.never
import org.mockito.kotlin.any
import org.mockito.kotlin.eq
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.springframework.http.HttpHeaders
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.security.crypto.password.PasswordEncoder
import java.time.Instant
import java.time.LocalDateTime
import java.util.Optional

@ExtendWith(org.mockito.junit.jupiter.MockitoExtension::class)
class AuthServiceTest {

    // RefreshToken validity is checked against LocalDateTime.now() in the service
    // So we need dates relative to actual current time for valid/expired token tests
    private val futureDateTime = LocalDateTime.now().plusDays(30)
    private val pastDateTime = LocalDateTime.now().minusDays(1)
    private val chromeUserAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    private val firefoxUserAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0"

    private val memberRepository: MemberRepository = mock()
    private val memberManagerRepository: MemberManagerRepository = mock()
    private val passwordEncoder: PasswordEncoder = mock()
    private val refreshTokenService: RefreshTokenService = mock()
    private val jwtProvider: JwtProvider = mock()
    private val loginAttemptService: LoginAttemptService = mock()
    private val entityManager: EntityManager = mock()
    private val jwtConfig = JwtConfig(secret = "secret", tokenValidityInSeconds = 1000, refreshTokenValidityInDays = 30)

    private lateinit var authService: AuthService

    @BeforeEach
    fun setUp() {
        authService = AuthService(
            memberRepository = memberRepository,
            memberManagerRepository = memberManagerRepository,
            passwordEncoder = passwordEncoder,
            refreshTokenService = refreshTokenService,
            jwtProvider = jwtProvider,
            jwtConfig = jwtConfig,
            loginAttemptService = loginAttemptService,
            entityManager = entityManager,
        )
    }

    @Test
    fun `tokenToLoginMember returns login member for valid token`() {
        val loginMember = LoginMember(id = 1L, name = "user", sessionId = 10L)
        val member = memberWithId(1L)
        whenever(jwtProvider.validateToken("token")).thenReturn(TokenStatus.VALID)
        whenever(jwtProvider.parseToken("token")).thenReturn(loginMember)
        whenever(refreshTokenService.isSessionActive(10L, 1L)).thenReturn(true)
        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(member))

        val result = authService.tokenToLoginMember("token")

        assertThat(result).isEqualTo(loginMember)
    }

    @Test
    fun `tokenToLoginMember allows legacy token until its JWT expiration without revoking refresh session`() {
        val member = memberWithId(1L)
        val loginMember = LoginMember(id = 1L, name = "user")
        whenever(jwtProvider.validateToken("legacy-token")).thenReturn(TokenStatus.VALID)
        whenever(jwtProvider.parseToken("legacy-token")).thenReturn(loginMember)
        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(member))

        val result = authService.tokenToLoginMember("legacy-token")

        assertThat(result).isEqualTo(loginMember)
        verify(refreshTokenService, never()).isSessionActive(any(), any())
    }

    @Test
    fun `tokenToLoginMember rejects revoked refresh session`() {
        whenever(jwtProvider.validateToken("revoked-token")).thenReturn(TokenStatus.VALID)
        whenever(jwtProvider.parseToken("revoked-token"))
            .thenReturn(LoginMember(id = 1L, name = "user", sessionId = 10L))
        whenever(refreshTokenService.isSessionActive(10L, 1L)).thenReturn(false)

        assertThrows<AuthException> {
            authService.tokenToLoginMember("revoked-token")
        }

        verify(memberRepository, never()).findById(any())
    }

    @Test
    fun `tokenToLoginMember rejects deletion pending member`() {
        val loginMember = LoginMember(id = 1L, name = "user", sessionId = 10L)
        val member = memberWithId(1L).also { it.markDeletionPending(Instant.parse("2026-08-12T00:00:00Z")) }
        whenever(jwtProvider.validateToken("token")).thenReturn(TokenStatus.VALID)
        whenever(jwtProvider.parseToken("token")).thenReturn(loginMember)
        whenever(refreshTokenService.isSessionActive(10L, 1L)).thenReturn(true)
        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(member))

        val exception = assertThrows<AuthException> {
            authService.tokenToLoginMember("token")
        }

        assertThat(exception.message).isEqualTo("auth.account.inactive")
    }

    @Test
    fun `tokenToLoginMember throws for invalid token`() {
        whenever(jwtProvider.validateToken("token")).thenReturn(TokenStatus.INVALID)

        assertThrows<AuthException> {
            authService.tokenToLoginMember("token")
        }
    }

    @Test
    fun `changePassword updates password when current matches`() {
        val member = memberWithId(1L)
        member.password = "encoded-old"
        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        whenever(passwordEncoder.matches("old-pass", "encoded-old")).thenReturn(true)
        whenever(passwordEncoder.encode("new-pass-1")).thenReturn("encoded-new")

        authService.changePassword(
            PasswordChangeDto(memberId = 1L, currentPassword = "old-pass", newPassword = "new-pass-1")
        )

        assertThat(member.password).isEqualTo("encoded-new")
        verify(refreshTokenService).revokeAllRefreshTokensByMember(member)
    }

    @Test
    fun `changePassword throws when current password does not match`() {
        val member = memberWithId(1L)
        member.password = "encoded-old"
        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        whenever(passwordEncoder.matches("old-pass", "encoded-old")).thenReturn(false)

        assertThrows<AuthException> {
            authService.changePassword(
                PasswordChangeDto(memberId = 1L, currentPassword = "old-pass", newPassword = "new-pass-1")
            )
        }

        verify(refreshTokenService, never()).revokeAllRefreshTokensByMember(any())
    }

    @Test
    fun `changePassword by admin skips current password check`() {
        val member = memberWithId(2L)
        member.password = "encoded-old"
        whenever(memberRepository.findById(2L)).thenReturn(Optional.of(member))
        whenever(passwordEncoder.encode("new-pass-1")).thenReturn("encoded-new")

        authService.changePassword(
            PasswordChangeDto(memberId = 2L, currentPassword = null, newPassword = "new-pass-1"),
            byAdmin = true
        )

        assertThat(member.password).isEqualTo("encoded-new")
    }

    @Test
    fun `getTokenResponse throws when rate limited`() {
        whenever(loginAttemptService.isBlocked("127.0.0.1", "user@duty.park")).thenReturn(true)
        val request = requestWith("127.0.0.1", "user@duty.park")

        assertThrows<RateLimitException> {
            authService.getTokenResponse(LoginDto("user@duty.park", "pass"), request)
        }

        verify(memberRepository, never()).findByEmail(any())
    }

    @Test
    fun `getTokenResponse records failed attempt on wrong password`() {
        val member = memberWithId(3L)
        member.password = "encoded-old"
        whenever(loginAttemptService.isBlocked("127.0.0.1", "user@duty.park")).thenReturn(false)
        whenever(memberRepository.findByEmail("user@duty.park")).thenReturn(Optional.of(member))
        whenever(passwordEncoder.matches("wrong", "encoded-old")).thenReturn(false)
        val request = requestWith("127.0.0.1", "user@duty.park")

        assertThrows<AuthException> {
            authService.getTokenResponse(LoginDto("user@duty.park", "wrong"), request)
        }

        verify(loginAttemptService).recordFailedAttempt("127.0.0.1", "user@duty.park")
        verify(loginAttemptService, never()).recordSuccessfulAttempt(any(), any())
    }

    @Test
    fun `getTokenResponse returns tokens on success`() {
        val member = memberWithId(4L)
        member.password = "encoded-pass"
        whenever(loginAttemptService.isBlocked("127.0.0.1", "user@duty.park")).thenReturn(false)
        whenever(memberRepository.findByEmail("user@duty.park")).thenReturn(Optional.of(member))
        whenever(passwordEncoder.matches("pass", "encoded-pass")).thenReturn(true)
        whenever(memberRepository.findMemberWithTeamForUpdate(4L)).thenReturn(Optional.of(member))
        val refreshToken = RefreshToken(
            member = member,
            validUntil = futureDateTime,
            remoteAddr = "127.0.0.1",
            userAgent = null
        )
        setRefreshTokenId(refreshToken, 40L)
        whenever(refreshTokenService.createRefreshToken(eq(4L), any(), any())).thenReturn(refreshToken)
        whenever(jwtProvider.createToken(member, 40L)).thenReturn("jwt-token")
        val request = requestWith("127.0.0.1", "user@duty.park")

        val result = authService.getTokenResponse(LoginDto("user@duty.park", "pass"), request)

        assertThat(result.accessToken).isEqualTo("jwt-token")
        assertThat(result.refreshToken).isEqualTo(refreshToken.token)
        assertThat(result.expiresIn).isEqualTo(1000)
        verify(entityManager).refresh(member)
        verify(loginAttemptService).recordSuccessfulAttempt("127.0.0.1", "user@duty.park")
    }

    @Test
    fun `getTokenResponse rejects deletion pending member`() {
        val member = memberWithId(4L).also { it.markDeletionPending(Instant.parse("2026-08-12T00:00:00Z")) }
        whenever(loginAttemptService.isBlocked("127.0.0.1", "user@duty.park")).thenReturn(false)
        whenever(memberRepository.findByEmail("user@duty.park")).thenReturn(Optional.of(member))
        val request = requestWith("127.0.0.1", "user@duty.park")

        val exception = assertThrows<AuthException> {
            authService.getTokenResponse(LoginDto("user@duty.park", "pass"), request)
        }

        assertThat(exception.message).isEqualTo("auth.login.failed")
        verify(loginAttemptService).recordFailedAttempt("127.0.0.1", "user@duty.park")
        verify(jwtProvider, never()).createToken(any<Member>(), any())
    }

    @Test
    fun `refreshAccessToken throws when token not found`() {
        whenever(refreshTokenService.findByToken("missing")).thenReturn(null)
        val request = requestWith("127.0.0.1", "user@duty.park")

        assertThrows<AuthException> {
            authService.refreshAccessToken("missing", request)
        }
    }

    @Test
    fun `refreshAccessToken throws when token expired`() {
        val member = memberWithId(5L)
        val refreshToken = RefreshToken(
            member = member,
            validUntil = pastDateTime,
            remoteAddr = "127.0.0.1",
            userAgent = null
        )
        setRefreshTokenId(refreshToken, 60L)
        whenever(refreshTokenService.findByToken("expired")).thenReturn(refreshToken)
        val request = requestWith("127.0.0.1", "user@duty.park")

        assertThrows<AuthException> {
            authService.refreshAccessToken("expired", request)
        }
    }

    @Test
    fun `refreshAccessToken updates validity for valid token`() {
        val member = memberWithId(6L)
        val refreshToken = RefreshToken(
            member = member,
            validUntil = futureDateTime,
            remoteAddr = "127.0.0.1",
            userAgent = chromeUserAgent
        )
        setRefreshTokenId(refreshToken, 60L)
        val before = refreshToken.validUntil
        whenever(refreshTokenService.findByToken("valid")).thenReturn(refreshToken)
        whenever(jwtProvider.createToken(member, 60L)).thenReturn("new-jwt")
        val request = requestWith("127.0.0.1", firefoxUserAgent)

        val result = authService.refreshAccessToken("valid", request)

        assertThat(result.accessToken).isEqualTo("new-jwt")
        assertThat(result.refreshToken).isEqualTo(refreshToken.token)
        assertThat(refreshToken.validUntil).isAfter(before)
        assertThat(refreshToken.userAgent).isEqualTo(firefoxUserAgent)
    }

    @Test
    fun `refreshAccessToken rejects deletion pending member`() {
        val member = memberWithId(6L).also { it.markDeletionPending(Instant.parse("2026-08-12T00:00:00Z")) }
        val refreshToken = RefreshToken(
            member = member,
            validUntil = futureDateTime,
            remoteAddr = "127.0.0.1",
            userAgent = chromeUserAgent
        )
        whenever(refreshTokenService.findByToken("valid")).thenReturn(refreshToken)
        val request = requestWith("127.0.0.1", firefoxUserAgent)

        val exception = assertThrows<AuthException> {
            authService.refreshAccessToken("valid", request)
        }

        assertThat(exception.message).isEqualTo("auth.account.inactive")
        verify(jwtProvider, never()).createToken(any<Member>(), any())
    }

    @Test
    fun `getTokenResponseByMemberId throws when member missing`() {
        whenever(memberRepository.findById(7L)).thenReturn(Optional.empty())
        val request = requestWith("127.0.0.1", "user@duty.park")

        assertThrows<AuthException> {
            authService.getTokenResponseByMemberId(7L, request)
        }
    }

    @Test
    fun `impersonate returns token when manager authorized`() {
        val manager = memberWithId(8L)
        val target = memberWithId(9L)
        whenever(memberRepository.findById(8L)).thenReturn(Optional.of(manager))
        whenever(memberRepository.findById(9L)).thenReturn(Optional.of(target))
        whenever(memberManagerRepository.findAllByManagerAndManaged(manager, target)).thenReturn(
            listOf(MemberManager(manager, target, ManagerRole.MANAGER))
        )
        whenever(jwtProvider.createImpersonationToken(target, 8L, 80L)).thenReturn("imp-token")

        val token = authService.impersonate(LoginMember(id = 8L, name = "manager", sessionId = 80L), 9L)

        assertThat(token).isEqualTo("imp-token")
    }

    @Test
    fun `legacy manager access token binds impersonation to its valid refresh cookie`() {
        val manager = memberWithId(8L)
        val target = memberWithId(9L)
        val refreshToken = RefreshToken(manager, futureDateTime, "127.0.0.1", "legacy")
        setRefreshTokenId(refreshToken, 80L)
        whenever(memberRepository.findById(8L)).thenReturn(Optional.of(manager))
        whenever(memberRepository.findById(9L)).thenReturn(Optional.of(target))
        whenever(memberManagerRepository.findAllByManagerAndManaged(manager, target)).thenReturn(
            listOf(MemberManager(manager, target, ManagerRole.MANAGER))
        )
        whenever(refreshTokenService.findByToken(refreshToken.token)).thenReturn(refreshToken)
        whenever(jwtProvider.createImpersonationToken(target, 8L, 80L)).thenReturn("imp-token")

        val token = authService.impersonate(
            LoginMember(id = 8L, name = "legacy-manager"),
            targetMemberId = 9L,
            legacyRefreshToken = refreshToken.token,
        )

        assertThat(token).isEqualTo("imp-token")
    }

    @Test
    fun `impersonate throws when not managing target`() {
        val manager = memberWithId(8L)
        val target = memberWithId(9L)
        whenever(memberRepository.findById(8L)).thenReturn(Optional.of(manager))
        whenever(memberRepository.findById(9L)).thenReturn(Optional.of(target))
        whenever(memberManagerRepository.findAllByManagerAndManaged(manager, target)).thenReturn(emptyList())

        assertThrows<AuthException> {
            authService.impersonate(LoginMember(id = 8L, name = "manager", sessionId = 80L), 9L)
        }
    }

    @Test
    fun `restore throws when not impersonating`() {
        val request = requestWith("127.0.0.1", "user@duty.park")

        assertThrows<AuthException> {
            authService.restore(LoginMember(id = 1L, name = "user"), null, request)
        }
    }

    @Test
    fun `tokenToLoginMember rejects suspended member`() {
        val loginMember = LoginMember(id = 1L, name = "user", sessionId = 10L)
        val member = memberWithId(1L).also { it.suspend() }
        whenever(jwtProvider.validateToken("token")).thenReturn(TokenStatus.VALID)
        whenever(jwtProvider.parseToken("token")).thenReturn(loginMember)
        whenever(refreshTokenService.isSessionActive(10L, 1L)).thenReturn(true)
        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(member))

        val exception = assertThrows<AuthException> {
            authService.tokenToLoginMember("token")
        }

        assertThat(exception.message).isEqualTo("auth.account.suspended")
    }

    @Test
    fun `getTokenResponse rejects suspended member with suspended code`() {
        val member = memberWithId(4L).also { it.suspend() }
        member.password = "encoded-pass"
        whenever(loginAttemptService.isBlocked("127.0.0.1", "user@duty.park")).thenReturn(false)
        whenever(memberRepository.findByEmail("user@duty.park")).thenReturn(Optional.of(member))
        whenever(passwordEncoder.matches("pass", "encoded-pass")).thenReturn(true)
        whenever(memberRepository.findMemberWithTeamForUpdate(4L)).thenReturn(Optional.of(member))
        val request = requestWith("127.0.0.1", "user@duty.park")

        val exception = assertThrows<AuthException> {
            authService.getTokenResponse(LoginDto("user@duty.park", "pass"), request)
        }

        assertThat(exception.message).isEqualTo("auth.account.suspended")
        verify(loginAttemptService, never()).recordFailedAttempt(any(), any())
        verify(jwtProvider, never()).createToken(any<Member>(), any())
    }

    @Test
    fun `getTokenResponse keeps the generic failure when a suspended member sends a wrong password`() {
        val member = memberWithId(4L).also { it.suspend() }
        member.password = "encoded-pass"
        whenever(loginAttemptService.isBlocked("127.0.0.1", "user@duty.park")).thenReturn(false)
        whenever(memberRepository.findByEmail("user@duty.park")).thenReturn(Optional.of(member))
        whenever(passwordEncoder.matches("wrong", "encoded-pass")).thenReturn(false)
        val request = requestWith("127.0.0.1", "user@duty.park")

        val exception = assertThrows<AuthException> {
            authService.getTokenResponse(LoginDto("user@duty.park", "wrong"), request)
        }

        assertThat(exception.message).isEqualTo("auth.login.failed")
        verify(loginAttemptService).recordFailedAttempt("127.0.0.1", "user@duty.park")
    }

    @Test
    fun `refreshAccessToken rejects suspended member`() {
        val member = memberWithId(6L).also { it.suspend() }
        val refreshToken = RefreshToken(
            member = member,
            validUntil = futureDateTime,
            remoteAddr = "127.0.0.1",
            userAgent = chromeUserAgent
        )
        whenever(refreshTokenService.findByToken("valid")).thenReturn(refreshToken)
        val request = requestWith("127.0.0.1", firefoxUserAgent)

        val exception = assertThrows<AuthException> {
            authService.refreshAccessToken("valid", request)
        }

        assertThat(exception.message).isEqualTo("auth.account.suspended")
    }

    @Test
    fun `impersonate rejects suspended target`() {
        val manager = memberWithId(8L)
        val target = memberWithId(9L).also { it.suspend() }
        whenever(memberRepository.findById(8L)).thenReturn(Optional.of(manager))
        whenever(memberRepository.findById(9L)).thenReturn(Optional.of(target))

        val exception = assertThrows<AuthException> {
            authService.impersonate(LoginMember(id = 8L, name = "manager", sessionId = 80L), 9L)
        }

        assertThat(exception.message).isEqualTo("auth.account.suspended")
    }

    @Test
    fun `verifyPasswordForReauth rejects suspended member`() {
        val member = memberWithId(1L).also { it.suspend() }
        member.password = "encoded-pass"
        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(member))

        val exception = assertThrows<AuthException> {
            authService.verifyPasswordForReauth(1L, "pass")
        }

        assertThat(exception.message).isEqualTo("auth.account.suspended")
    }

    private fun requestWith(ip: String, userAgent: String = "test-agent"): MockHttpServletRequest {
        val request = MockHttpServletRequest()
        request.remoteAddr = ip
        request.addHeader(HttpHeaders.USER_AGENT, userAgent)
        return request
    }

    private fun memberWithId(id: Long): Member {
        val member = Member("user$id", "user$id@duty.park", "pass")
        val field = Member::class.java.getDeclaredField("id")
        field.isAccessible = true
        field.set(member, id)
        return member
    }

    private fun setRefreshTokenId(refreshToken: RefreshToken, id: Long) {
        val field = RefreshToken::class.java.getDeclaredField("id")
        field.isAccessible = true
        field.set(refreshToken, id)
    }
}
