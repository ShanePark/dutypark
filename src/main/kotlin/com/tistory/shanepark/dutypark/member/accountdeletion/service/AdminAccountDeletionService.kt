package com.tistory.shanepark.dutypark.member.accountdeletion.service

import com.tistory.shanepark.dutypark.member.accountdeletion.dto.AccountDeletionRetryResponse
import com.tistory.shanepark.dutypark.member.accountdeletion.exception.AccountDeletionException
import com.tistory.shanepark.dutypark.member.accountdeletion.repository.AccountDeletionJobRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.Duration

@Service
class AdminAccountDeletionService(
    private val jobRepository: AccountDeletionJobRepository,
    private val clock: Clock,
) {
    @Transactional
    fun retryFailed(jobId: Long): AccountDeletionRetryResponse {
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

        return AccountDeletionRetryResponse(jobId = jobId, status = "PENDING")
    }

    companion object {
        private val EXPECTED_COMPLETION_TIME: Duration = Duration.ofMinutes(5)
    }
}
