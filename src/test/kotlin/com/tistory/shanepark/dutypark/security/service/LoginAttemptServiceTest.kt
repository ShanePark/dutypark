package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.security.repository.LoginAttemptRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired

class LoginAttemptServiceTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var loginAttemptService: LoginAttemptService

    @Autowired
    lateinit var loginAttemptRepository: LoginAttemptRepository

    private val testIp = "192.168.1.100"
    private val testEmail = "test@example.com"

    @BeforeEach
    fun cleanup() {
        loginAttemptRepository.deleteAll()
    }

    @Test
    fun `should not be blocked with no failed attempts`() {
        assertThat(loginAttemptService.isBlocked(testIp, testEmail)).isFalse()
    }

    @Test
    fun `should not be blocked with less than max failed attempts`() {
        repeat(4) {
            loginAttemptService.recordFailedAttempt(testIp, testEmail)
        }
        assertThat(loginAttemptService.isBlocked(testIp, testEmail)).isFalse()
    }

    @Test
    fun `should be blocked after max failed attempts`() {
        repeat(5) {
            loginAttemptService.recordFailedAttempt(testIp, testEmail)
        }
        assertThat(loginAttemptService.isBlocked(testIp, testEmail)).isTrue()
    }

    @Test
    fun `different IP should not affect blocking`() {
        repeat(5) {
            loginAttemptService.recordFailedAttempt(testIp, testEmail)
        }
        assertThat(loginAttemptService.isBlocked("192.168.1.200", testEmail)).isFalse()
    }

    @Test
    fun `different email should not affect blocking`() {
        repeat(5) {
            loginAttemptService.recordFailedAttempt(testIp, testEmail)
        }
        assertThat(loginAttemptService.isBlocked(testIp, "other@example.com")).isFalse()
    }

    @Test
    fun `email comparison should be case insensitive`() {
        repeat(3) {
            loginAttemptService.recordFailedAttempt(testIp, "Test@Example.COM")
        }
        repeat(2) {
            loginAttemptService.recordFailedAttempt(testIp, "test@example.com")
        }
        assertThat(loginAttemptService.isBlocked(testIp, "TEST@EXAMPLE.com")).isTrue()
    }

    @Test
    fun `successful attempt should be recorded`() {
        loginAttemptService.recordSuccessfulAttempt(testIp, testEmail)
        val attempts = loginAttemptRepository.findAll()
        assertThat(attempts).hasSize(1)
        assertThat(attempts[0].success).isTrue()
    }

    @Test
    fun `getRemainingAttempts should return correct count`() {
        assertThat(loginAttemptService.getRemainingAttempts(testIp, testEmail)).isEqualTo(5)

        repeat(3) {
            loginAttemptService.recordFailedAttempt(testIp, testEmail)
        }
        assertThat(loginAttemptService.getRemainingAttempts(testIp, testEmail)).isEqualTo(2)
    }

    @Test
    fun `getRemainingAttempts should return zero when blocked`() {
        repeat(5) {
            loginAttemptService.recordFailedAttempt(testIp, testEmail)
        }
        assertThat(loginAttemptService.getRemainingAttempts(testIp, testEmail)).isEqualTo(0)
    }

    @Test
    fun `successful attempts should not count towards blocking`() {
        repeat(5) {
            loginAttemptService.recordSuccessfulAttempt(testIp, testEmail)
        }
        assertThat(loginAttemptService.isBlocked(testIp, testEmail)).isFalse()
    }

}
