package com.tistory.shanepark.dutypark.member.accountdeletion.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.logging.auditEventAfterCommit
import com.tistory.shanepark.dutypark.common.logging.toAuditActor
import com.tistory.shanepark.dutypark.member.accountdeletion.dto.AccountDeletionRetryResponse
import com.tistory.shanepark.dutypark.member.accountdeletion.exception.AccountDeletionException
import com.tistory.shanepark.dutypark.member.accountdeletion.repository.AccountDeletionJobRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.Duration

@Service
class AdminAccountDeletionService(
    private val jobRepository: AccountDeletionJobRepository,
    private val clock: Clock,
) {
    private val log = logger()

    @Transactional
    fun retryFailed(jobId: Long, actor: LoginMember? = null): AccountDeletionRetryResponse {
        val now = clock.instant()
        val updated = jobRepository.retryFailed(
            jobId = jobId,
            nextAttemptAt = now,
            estimatedCompletionAt = now.plus(EXPECTED_COMPLETION_TIME),
        )
        if (updated == 0) {
            if (!jobRepository.existsById(jobId)) {
                throw AccountDeletionException("accountDeletion.job.notFound", 404)
            }
            throw AccountDeletionException("accountDeletion.job.retryNotAllowed", 409)
        }

        log.auditEventAfterCommit(
            event = "account_deletion.retry_requested", actor = actor?.toAuditActor(),
            target = mapOf("jobId" to jobId), details = mapOf("previousStatus" to "FAILED", "status" to "PENDING"),
        )
        return AccountDeletionRetryResponse(jobId = jobId, status = "PENDING")
    }

    companion object {
        private val EXPECTED_COMPLETION_TIME: Duration = Duration.ofMinutes(5)
    }
}
