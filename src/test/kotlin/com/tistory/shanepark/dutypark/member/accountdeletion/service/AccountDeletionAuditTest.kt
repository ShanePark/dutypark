package com.tistory.shanepark.dutypark.member.accountdeletion.service

import com.tistory.shanepark.dutypark.member.accountdeletion.repository.AccountDeletionJobRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.kotlin.any
import org.mockito.kotlin.eq
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import java.time.Clock

class AccountDeletionAuditTest {
    @Test
    fun `deletion acceptance logs impact without password receipt or identity`() {
        val repository: AccountDeletionJobRepository = mock()
        val members: com.tistory.shanepark.dutypark.member.repository.MemberRepository = mock()
        val managers: com.tistory.shanepark.dutypark.member.repository.MemberManagerRepository = mock()
        val sessions: com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository = mock()
        val encoder: org.springframework.security.crypto.password.PasswordEncoder = mock()
        val member = com.tistory.shanepark.dutypark.member.domain.entity.Member("member", password = "private-password-hash")
        org.springframework.test.util.ReflectionTestUtils.setField(member, "id", 1L)
        whenever(repository.findByRootMemberIdForUpdate(1L)).thenReturn(java.util.Optional.empty())
        whenever(members.findMemberWithTeamForUpdate(1L)).thenReturn(java.util.Optional.of(member))
        whenever(managers.findAllByManager(member)).thenReturn(emptyList())
        whenever(sessions.findAllByMemberIdIn(listOf(1L))).thenReturn(emptyList())
        whenever(encoder.matches("private-password", member.password)).thenReturn(true)
        whenever(repository.save(any<com.tistory.shanepark.dutypark.member.accountdeletion.domain.AccountDeletionJob>()))
            .thenAnswer { (it.arguments[0] as com.tistory.shanepark.dutypark.member.accountdeletion.domain.AccountDeletionJob).also { job ->
                org.springframework.test.util.ReflectionTestUtils.setField(job, "id", 42L)
            } }
        val service = AccountDeletionService(members, managers, mock(), sessions, mock(), repository, mock(), encoder, mock(), Clock.systemUTC())
        val logger = org.slf4j.LoggerFactory.getLogger(AccountDeletionService::class.java) as ch.qos.logback.classic.Logger
        val appender = ch.qos.logback.core.read.ListAppender<ch.qos.logback.classic.spi.ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try {
            val response = service.requestDeletion(
                com.tistory.shanepark.dutypark.security.domain.dto.LoginMember(id = 1L, name = "member"),
                com.tistory.shanepark.dutypark.member.accountdeletion.dto.AccountDeletionRequest("DELETE", password = "private-password"),
            )
            assertThat(appender.list.single().formattedMessage)
                .contains("account_deletion.requested", "42", "targetMemberCount", "PENDING")
                .doesNotContain("private-password", "private-password-hash", response.receiptToken!!)
        } finally {
            logger.detachAppender(appender)
            appender.stop()
        }
    }

    @Test
    fun `retry logs accepted job without failure contents`() {
        val repository: AccountDeletionJobRepository = mock()
        whenever(repository.retryFailed(eq(42L), any(), any())).thenReturn(1)
        val service = AdminAccountDeletionService(repository, Clock.systemUTC())
        val logger = org.slf4j.LoggerFactory.getLogger(AdminAccountDeletionService::class.java) as ch.qos.logback.classic.Logger
        val appender = ch.qos.logback.core.read.ListAppender<ch.qos.logback.classic.spi.ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try {
            service.retryFailed(42L)
            assertThat(appender.list.single().formattedMessage).contains("account_deletion.retry_requested", "42", "PENDING")
        } finally {
            logger.detachAppender(appender)
            appender.stop()
        }
    }
}
