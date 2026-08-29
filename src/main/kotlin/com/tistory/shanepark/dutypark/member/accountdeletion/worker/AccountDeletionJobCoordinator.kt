package com.tistory.shanepark.dutypark.member.accountdeletion.worker

import com.tistory.shanepark.dutypark.member.accountdeletion.domain.AccountDeletionJobStatus
import com.tistory.shanepark.dutypark.member.accountdeletion.repository.AccountDeletionJobRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.Duration
import java.util.UUID

@Service
class AccountDeletionJobCoordinator(
    private val jobRepository: AccountDeletionJobRepository,
    private val clock: Clock,
) {
    @Transactional
    fun claimNext(): AccountDeletionClaim? {
        val now = clock.instant()
        val job = jobRepository.findNextClaimableForUpdate(now, now.minus(STALE_AFTER)).orElse(null) ?: return null
        val leaseToken = UUID.randomUUID().toString()
        job.claim(now, leaseToken)
        return AccountDeletionClaim(requireNotNull(job.id), leaseToken)
    }

    @Transactional
    fun markCompleted(claim: AccountDeletionClaim): Boolean {
        val completedAt = clock.instant()
        return jobRepository.markCompletedIfLeaseMatches(
            jobId = claim.jobId,
            leaseToken = claim.leaseToken,
            completedAt = completedAt,
            receiptExpiresAt = completedAt.plus(RECEIPT_RETENTION),
        ) == 1
    }

    @Transactional
    fun markFailure(claim: AccountDeletionClaim, errorCode: String): Boolean {
        val job = jobRepository.findById(claim.jobId).orElse(null) ?: return false
        if (job.status != AccountDeletionJobStatus.PROCESSING || job.leaseToken != claim.leaseToken) {
            return false
        }

        val failedAt = clock.instant()
        val terminal = job.attemptCount >= MAX_ATTEMPTS
        val status = if (terminal) AccountDeletionJobStatus.FAILED else AccountDeletionJobStatus.RETRY_WAIT
        val nextAttemptAt = if (terminal) job.nextAttemptAt else failedAt.plus(RETRY_DELAYS[job.attemptCount - 1])
        val receiptExpiresAt = if (terminal) failedAt.plus(RECEIPT_RETENTION) else null
        return jobRepository.markFailureIfLeaseMatches(
            jobId = claim.jobId,
            leaseToken = claim.leaseToken,
            status = status,
            nextAttemptAt = nextAttemptAt,
            lastError = errorCode,
            receiptExpiresAt = receiptExpiresAt,
        ) == 1
    }

    @Transactional
    fun clearExpiredReceiptTokenHashes(): Int {
        return jobRepository.clearExpiredReceiptTokenHashes(clock.instant())
    }

    companion object {
        // The lease guards state transitions, but cleanup side effects can still be repeated.
        // Keep reclaim slower than a normally long-running cleanup until heartbeats exist.
        private val STALE_AFTER: Duration = Duration.ofMinutes(15)
        private const val MAX_ATTEMPTS = 8
        private val RECEIPT_RETENTION: Duration = Duration.ofDays(30)
        /** Seven retry waits total 245 seconds, leaving the five-minute estimate usable. */
        private val RETRY_DELAYS = listOf(
            Duration.ofSeconds(5),
            Duration.ofSeconds(10),
            Duration.ofSeconds(20),
            Duration.ofSeconds(30),
            Duration.ofSeconds(45),
            Duration.ofSeconds(60),
            Duration.ofSeconds(75),
        )
    }
}
