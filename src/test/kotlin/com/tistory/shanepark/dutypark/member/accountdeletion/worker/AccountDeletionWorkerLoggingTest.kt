package com.tistory.shanepark.dutypark.member.accountdeletion.worker

import ch.qos.logback.classic.Logger
import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.core.read.ListAppender
import com.tistory.shanepark.dutypark.member.accountdeletion.repository.AccountDeletionTargetMemberRepository
import com.tistory.shanepark.dutypark.member.accountdeletion.repository.AccountDeletionTargetTeamRepository
import com.tistory.shanepark.dutypark.member.accountdeletion.service.AccountDeletionExternalAccountRevoker
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.kotlin.any
import org.mockito.kotlin.eq
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import org.slf4j.LoggerFactory

class AccountDeletionWorkerLoggingTest {
    private val coordinator: AccountDeletionJobCoordinator = mock()
    private val targetMemberRepository: AccountDeletionTargetMemberRepository = mock()
    private val targetTeamRepository: AccountDeletionTargetTeamRepository = mock()
    private val externalAccountRevoker: AccountDeletionExternalAccountRevoker = mock()
    private val fileCleaner: AccountDeletionFileCleaner = mock()
    private val databaseCleaner: AccountDeletionDatabaseCleaner = mock()

    private val worker = AccountDeletionWorker(
        coordinator = coordinator,
        targetMemberRepository = targetMemberRepository,
        targetTeamRepository = targetTeamRepository,
        externalAccountRevoker = externalAccountRevoker,
        fileCleaner = fileCleaner,
        databaseCleaner = databaseCleaner,
    )

    @Test
    fun `worker failure logs job and phase without lease or member details`() {
        val claim = AccountDeletionClaim(jobId = 88L, leaseToken = "private-lease-token")
        whenever(coordinator.claimNext()).thenReturn(claim, null)
        whenever(targetMemberRepository.findAllByJobId(claim.jobId)).thenReturn(emptyList())
        whenever(targetTeamRepository.findAllByJobId(claim.jobId)).thenReturn(emptyList())
        whenever(coordinator.markFailure(eq(claim), any())).thenReturn(true)
        val logger = LoggerFactory.getLogger(AccountDeletionWorker::class.java) as Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)

        try {
            worker.processPendingJobs()
        } finally {
            logger.detachAppender(appender)
        }

        val event = appender.list.single()
        assertThat(event.formattedMessage)
            .contains("account_deletion_job_failed", "88", "IllegalStateException")
            .doesNotContain("private-lease-token", "memberName", "email", "rootMemberId")
    }
}
