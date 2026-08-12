package com.tistory.shanepark.dutypark.member.accountdeletion.worker

import com.tistory.shanepark.dutypark.member.accountdeletion.repository.AccountDeletionJobRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.Duration

@Service
class AccountDeletionJobCoordinator(
    private val jobRepository: AccountDeletionJobRepository,
    private val clock: Clock,
) {
    @Transactional
    fun claimNext(): Long? {
        val now = clock.instant()
        val job = jobRepository.findNextClaimableForUpdate(now, now.minus(STALE_AFTER)).orElse(null) ?: return null
        job.claim(now)
        return requireNotNull(job.id)
    }

    @Transactional
    fun markCompleted(jobId: Long) {
        val job = jobRepository.findById(jobId).orElseThrow()
        job.markCompleted(clock.instant())
    }

    @Transactional
    fun markFailure(jobId: Long, errorCode: String) {
        val job = jobRepository.findById(jobId).orElseThrow()
        if (job.attemptCount >= MAX_ATTEMPTS) {
            job.markFailed(errorCode)
            return
        }
        val delayMinutes = 1L shl (job.attemptCount - 1).coerceIn(0, 6)
        job.scheduleRetry(clock.instant().plus(Duration.ofMinutes(delayMinutes)), errorCode)
    }

    companion object {
        private val STALE_AFTER: Duration = Duration.ofMinutes(15)
        private const val MAX_ATTEMPTS = 8
    }
}
