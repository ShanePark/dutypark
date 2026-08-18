package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.admin.service.AdminService
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.MemberStatus
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.kotlin.doAnswer
import org.mockito.kotlin.whenever
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.test.context.bean.override.mockito.MockitoBean
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.transaction.support.TransactionTemplate
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

@SpringBootTest
class AuthServiceSuspensionConcurrencyIntegrationTest {

    @Autowired lateinit var authService: AuthService
    @Autowired lateinit var adminService: AdminService
    @Autowired lateinit var memberRepository: MemberRepository
    @Autowired lateinit var refreshTokenRepository: RefreshTokenRepository
    @Autowired lateinit var passwordEncoder: PasswordEncoder
    @Autowired lateinit var transactionTemplate: TransactionTemplate

    @MockitoBean lateinit var loginAttemptService: LoginAttemptService

    @Test
    fun `suspension racing a successful login leaves no active session`() {
        val suffix = System.nanoTime().toString()
        val email = "login-suspension-$suffix@duty.park"
        val password = "race-password"
        val memberId = transactionTemplate.execute {
            memberRepository.saveAndFlush(
                Member(
                    name = "login-race",
                    email = email,
                    password = passwordEncoder.encode(password),
                )
            ).id
        }!!

        val loginPassedStatusCheck = CountDownLatch(1)
        val allowLoginToCreateSession = CountDownLatch(1)
        val suspensionStarted = CountDownLatch(1)
        val suspensionFinished = CountDownLatch(1)
        whenever(loginAttemptService.isBlocked("198.51.100.10", email)).thenReturn(false)
        doAnswer {
            loginPassedStatusCheck.countDown()
            check(allowLoginToCreateSession.await(10, TimeUnit.SECONDS))
            null
        }.whenever(loginAttemptService).recordSuccessfulAttempt("198.51.100.10", email)

        val executor = Executors.newFixedThreadPool(2)
        try {
            val loginFuture = executor.submit {
                authService.getTokenResponse(
                    LoginDto(email = email, password = password, rememberMe = false),
                    MockHttpServletRequest().apply {
                        remoteAddr = "198.51.100.10"
                    },
                )
            }
            check(loginPassedStatusCheck.await(10, TimeUnit.SECONDS))

            val suspensionFuture = executor.submit {
                suspensionStarted.countDown()
                try {
                    adminService.suspendMember(memberId)
                } finally {
                    suspensionFinished.countDown()
                }
            }
            check(suspensionStarted.await(10, TimeUnit.SECONDS))

            // Without a shared member-row lock, suspension completes here and the paused login
            // creates a new refresh token afterwards. With the lock, suspension waits and revokes it.
            suspensionFinished.await(1, TimeUnit.SECONDS)
            allowLoginToCreateSession.countDown()

            loginFuture.get(10, TimeUnit.SECONDS)
            suspensionFuture.get(10, TimeUnit.SECONDS)

            val (status, refreshTokenCount) = transactionTemplate.execute {
                val member = memberRepository.findById(memberId).orElseThrow()
                member.status to refreshTokenRepository.findAllByMemberIdOrderByLastUsedDesc(memberId).size
            }
            assertThat(status).isEqualTo(MemberStatus.SUSPENDED)
            assertThat(refreshTokenCount).isZero()
        } finally {
            allowLoginToCreateSession.countDown()
            executor.shutdownNow()
            executor.awaitTermination(5, TimeUnit.SECONDS)
            transactionTemplate.execute {
                refreshTokenRepository.deleteAll(
                    refreshTokenRepository.findAllByMemberIdOrderByLastUsedDesc(memberId)
                )
                memberRepository.deleteById(memberId)
            }
        }
    }
}
