package com.tistory.shanepark.dutypark.member.accountdeletion.domain

import jakarta.persistence.CascadeType
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.EnumType
import jakarta.persistence.Enumerated
import jakarta.persistence.GeneratedValue
import jakarta.persistence.GenerationType
import jakarta.persistence.Id
import jakarta.persistence.OneToMany
import jakarta.persistence.Table
import java.time.Instant

@Entity
@Table(name = "account_deletion_job")
class AccountDeletionJob(
    @Column(name = "root_member_id", nullable = false, unique = true)
    val rootMemberId: Long,

    @Column(name = "delete_team_id")
    val deleteTeamId: Long? = null,

    @Column(name = "replacement_manager_id")
    val replacementManagerId: Long? = null,

    @Column(name = "next_attempt_at", nullable = false)
    var nextAttemptAt: Instant,

    @Column(name = "created_at", nullable = false, updatable = false)
    val createdAt: Instant,
) {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
        protected set

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    var status: AccountDeletionJobStatus = AccountDeletionJobStatus.PENDING
        protected set

    @Column(name = "attempt_count", nullable = false)
    var attemptCount: Int = 0
        protected set

    @Column(name = "locked_at")
    var lockedAt: Instant? = null
        protected set

    @Column(name = "last_error", columnDefinition = "text")
    var lastError: String? = null
        protected set

    @Column(name = "completed_at")
    var completedAt: Instant? = null
        protected set

    @OneToMany(mappedBy = "job", cascade = [CascadeType.ALL], orphanRemoval = true)
    val targetMembers: MutableSet<AccountDeletionTargetMember> = linkedSetOf()

    @OneToMany(mappedBy = "job", cascade = [CascadeType.ALL], orphanRemoval = true)
    val targetTeams: MutableSet<AccountDeletionTargetTeam> = linkedSetOf()

    fun addTargetMember(memberId: Long) {
        if (targetMembers.none { it.memberId == memberId }) {
            targetMembers.add(AccountDeletionTargetMember(job = this, memberId = memberId))
        }
    }

    fun addTargetTeam(teamId: Long) {
        if (targetTeams.none { it.teamId == teamId }) {
            targetTeams.add(AccountDeletionTargetTeam(job = this, teamId = teamId))
        }
    }

    fun claim(now: Instant) {
        check(status == AccountDeletionJobStatus.PENDING ||
            status == AccountDeletionJobStatus.RETRY_WAIT ||
            status == AccountDeletionJobStatus.PROCESSING)
        status = AccountDeletionJobStatus.PROCESSING
        attemptCount++
        lockedAt = now
        lastError = null
    }

    fun scheduleRetry(nextAttemptAt: Instant, error: String) {
        check(status == AccountDeletionJobStatus.PROCESSING)
        status = AccountDeletionJobStatus.RETRY_WAIT
        this.nextAttemptAt = nextAttemptAt
        lockedAt = null
        lastError = error.take(MAX_ERROR_LENGTH)
    }

    fun markFailed(error: String) {
        check(status == AccountDeletionJobStatus.PROCESSING)
        status = AccountDeletionJobStatus.FAILED
        lockedAt = null
        lastError = error.take(MAX_ERROR_LENGTH)
    }

    fun markCompleted(completedAt: Instant) {
        check(status == AccountDeletionJobStatus.PROCESSING)
        status = AccountDeletionJobStatus.COMPLETED
        lockedAt = null
        lastError = null
        this.completedAt = completedAt
    }

    companion object {
        private const val MAX_ERROR_LENGTH = 4_000
    }
}
