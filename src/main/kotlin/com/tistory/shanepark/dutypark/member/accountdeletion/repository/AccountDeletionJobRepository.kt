package com.tistory.shanepark.dutypark.member.accountdeletion.repository

import com.tistory.shanepark.dutypark.member.accountdeletion.domain.AccountDeletionJob
import jakarta.persistence.LockModeType
import jakarta.persistence.QueryHint
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Lock
import org.springframework.data.jpa.repository.Modifying
import org.springframework.data.jpa.repository.Query
import org.springframework.data.jpa.repository.QueryHints
import java.time.Instant
import java.util.Optional

interface AccountDeletionJobRepository : JpaRepository<AccountDeletionJob, Long> {
    fun findByRootMemberId(rootMemberId: Long): AccountDeletionJob?

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @QueryHints(QueryHint(name = "jakarta.persistence.lock.timeout", value = "5000"))
    @Query("select j from AccountDeletionJob j where j.rootMemberId = :rootMemberId")
    fun findByRootMemberIdForUpdate(rootMemberId: Long): Optional<AccountDeletionJob>

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query(
        """
            update AccountDeletionJob j
            set j.status = com.tistory.shanepark.dutypark.member.accountdeletion.domain.AccountDeletionJobStatus.PENDING,
                j.attemptCount = 0,
                j.nextAttemptAt = :nextAttemptAt,
                j.lockedAt = null,
                j.lastError = null,
                j.completedAt = null
            where j.id = :jobId
              and j.status = com.tistory.shanepark.dutypark.member.accountdeletion.domain.AccountDeletionJobStatus.FAILED
        """
    )
    fun retryFailed(jobId: Long, nextAttemptAt: Instant): Int

    @Query(
        value = """
            select *
            from account_deletion_job
            where (
                status in ('PENDING', 'RETRY_WAIT')
                and next_attempt_at <= :now
            ) or (
                status = 'PROCESSING'
                and locked_at < :staleBefore
            )
            order by next_attempt_at, id
            limit 1
            for update skip locked
        """,
        nativeQuery = true,
    )
    fun findNextClaimableForUpdate(now: Instant, staleBefore: Instant): Optional<AccountDeletionJob>
}
