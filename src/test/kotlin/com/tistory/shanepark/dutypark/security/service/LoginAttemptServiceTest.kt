package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.security.config.LoginRateLimitConfig
import com.tistory.shanepark.dutypark.security.domain.entity.LoginAttempt
import com.tistory.shanepark.dutypark.security.repository.LoginAttemptRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.ArgumentCaptor
import org.mockito.Captor
import org.mockito.Mock
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.any
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import java.time.Clock
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId

@ExtendWith(MockitoExtension::class)
class LoginAttemptServiceTest {

    @Mock
    lateinit var loginAttemptRepository: LoginAttemptRepository

    @Captor
    lateinit var loginAttemptCaptor: ArgumentCaptor<LoginAttempt>

    private lateinit var loginAttemptService: LoginAttemptService
    private lateinit var config: LoginRateLimitConfig
    private lateinit var clock: Clock

    private val testIp = "192.168.1.100"
    private val testEmail = "test@example.com"
    private val fixedInstant = Instant.parse("2024-01-15T10:00:00Z")
    private val zoneId = ZoneId.of("UTC")

    @BeforeEach
    fun setup() {
        config = LoginRateLimitConfig(maxAttempts = 5, windowMinutes = 15)
        clock = Clock.fixed(fixedInstant, zoneId)
        loginAttemptService = LoginAttemptService(loginAttemptRepository, config, clock)
    }

    @Test
    fun `should not be blocked with no failed attempts`() {
        whenever(loginAttemptRepository.countRecentFailedAttempts(any(), any(), any())).thenReturn(0)

        assertThat(loginAttemptService.isBlocked(testIp, testEmail)).isFalse()
    }

    @Test
    fun `should not be blocked with less than max failed attempts`() {
        whenever(loginAttemptRepository.countRecentFailedAttempts(any(), any(), any())).thenReturn(4)

        assertThat(loginAttemptService.isBlocked(testIp, testEmail)).isFalse()
    }

    @Test
    fun `should be blocked after max failed attempts`() {
        whenever(loginAttemptRepository.countRecentFailedAttempts(any(), any(), any())).thenReturn(5)

        assertThat(loginAttemptService.isBlocked(testIp, testEmail)).isTrue()
    }

    @Test
    fun `different IP should not affect blocking`() {
        val differentIp = "192.168.1.200"
        val expectedSince = LocalDateTime.now(clock).minusMinutes(config.windowMinutes)

        whenever(
            loginAttemptRepository.countRecentFailedAttempts(
                ipAddress = differentIp,
                email = testEmail,
                since = expectedSince
            )
        ).thenReturn(0)

        assertThat(loginAttemptService.isBlocked(differentIp, testEmail)).isFalse()
    }

    @Test
    fun `different email should not affect blocking`() {
        val differentEmail = "other@example.com"
        val expectedSince = LocalDateTime.now(clock).minusMinutes(config.windowMinutes)

        whenever(
            loginAttemptRepository.countRecentFailedAttempts(
                ipAddress = testIp,
                email = differentEmail,
                since = expectedSince
            )
        ).thenReturn(0)

        assertThat(loginAttemptService.isBlocked(testIp, differentEmail)).isFalse()
    }

    @Test
    fun `email comparison should be case insensitive`() {
        val mixedCaseEmail = "TEST@EXAMPLE.com"
        val expectedSince = LocalDateTime.now(clock).minusMinutes(config.windowMinutes)

        whenever(
            loginAttemptRepository.countRecentFailedAttempts(
                ipAddress = testIp,
                email = mixedCaseEmail.lowercase(),
                since = expectedSince
            )
        ).thenReturn(5)

        assertThat(loginAttemptService.isBlocked(testIp, mixedCaseEmail)).isTrue()
    }

    @Test
    fun `successful attempt should be recorded with correct values`() {
        loginAttemptService.recordSuccessfulAttempt(testIp, testEmail)

        verify(loginAttemptRepository).save(loginAttemptCaptor.capture())
        val savedAttempt = loginAttemptCaptor.value

        assertThat(savedAttempt.ipAddress).isEqualTo(testIp)
        assertThat(savedAttempt.email).isEqualTo(testEmail.lowercase())
        assertThat(savedAttempt.attemptTime).isEqualTo(LocalDateTime.now(clock))
        assertThat(savedAttempt.success).isTrue()
    }

    @Test
    fun `failed attempt should be recorded with correct values`() {
        loginAttemptService.recordFailedAttempt(testIp, testEmail)

        verify(loginAttemptRepository).save(loginAttemptCaptor.capture())
        val savedAttempt = loginAttemptCaptor.value

        assertThat(savedAttempt.ipAddress).isEqualTo(testIp)
        assertThat(savedAttempt.email).isEqualTo(testEmail.lowercase())
        assertThat(savedAttempt.attemptTime).isEqualTo(LocalDateTime.now(clock))
        assertThat(savedAttempt.success).isFalse()
    }

    @Test
    fun `getRemainingAttempts should return correct count`() {
        whenever(loginAttemptRepository.countRecentFailedAttempts(any(), any(), any())).thenReturn(3)

        assertThat(loginAttemptService.getRemainingAttempts(testIp, testEmail)).isEqualTo(2)
    }

    @Test
    fun `getRemainingAttempts should return zero when blocked`() {
        whenever(loginAttemptRepository.countRecentFailedAttempts(any(), any(), any())).thenReturn(5)

        assertThat(loginAttemptService.getRemainingAttempts(testIp, testEmail)).isEqualTo(0)
    }

    @Test
    fun `getRemainingAttempts should return zero when exceeded max attempts`() {
        whenever(loginAttemptRepository.countRecentFailedAttempts(any(), any(), any())).thenReturn(7)

        assertThat(loginAttemptService.getRemainingAttempts(testIp, testEmail)).isEqualTo(0)
    }

    @Test
    fun `successful attempts should not count towards blocking`() {
        whenever(loginAttemptRepository.countRecentFailedAttempts(any(), any(), any())).thenReturn(0)

        assertThat(loginAttemptService.isBlocked(testIp, testEmail)).isFalse()
    }

    @Test
    fun `recordFailedAttempt should convert email to lowercase`() {
        val upperCaseEmail = "TEST@EXAMPLE.COM"

        loginAttemptService.recordFailedAttempt(testIp, upperCaseEmail)

        verify(loginAttemptRepository).save(loginAttemptCaptor.capture())
        assertThat(loginAttemptCaptor.value.email).isEqualTo("test@example.com")
    }

    @Test
    fun `recordSuccessfulAttempt should convert email to lowercase`() {
        val upperCaseEmail = "TEST@EXAMPLE.COM"

        loginAttemptService.recordSuccessfulAttempt(testIp, upperCaseEmail)

        verify(loginAttemptRepository).save(loginAttemptCaptor.capture())
        assertThat(loginAttemptCaptor.value.email).isEqualTo("test@example.com")
    }

}
