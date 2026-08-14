package com.tistory.shanepark.dutypark.member.accountdeletion.service

import com.tistory.shanepark.dutypark.member.accountdeletion.dto.AccountDeletionRetryResponse
import com.tistory.shanepark.dutypark.member.accountdeletion.exception.AccountDeletionException
import com.tistory.shanepark.dutypark.member.accountdeletion.repository.AccountDeletionJobRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock

@Service
class AdminAccountDeletionService(
    private val jobRepository: AccountDeletionJobRepository,
    private val clock: Clock,
) {
    @Transactional
    fun retryFailed(jobId: Long): AccountDeletionRetryResponse {
        val updated = jobRepository.retryFailed(jobId, clock.instant())
        if (updated == 0) {
            if (!jobRepository.existsById(jobId)) {
                throw AccountDeletionException("accountDeletion.job.notFound", 404)
            }
            throw AccountDeletionException("accountDeletion.job.retryNotAllowed", 409)
        }

        return AccountDeletionRetryResponse(jobId = jobId, status = "PENDING")
    }
}
