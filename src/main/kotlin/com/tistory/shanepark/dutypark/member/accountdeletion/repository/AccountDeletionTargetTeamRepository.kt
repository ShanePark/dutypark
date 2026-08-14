package com.tistory.shanepark.dutypark.member.accountdeletion.repository

import com.tistory.shanepark.dutypark.member.accountdeletion.domain.AccountDeletionTargetTeam
import org.springframework.data.jpa.repository.JpaRepository

interface AccountDeletionTargetTeamRepository : JpaRepository<AccountDeletionTargetTeam, Long> {
    fun findAllByJobId(jobId: Long): List<AccountDeletionTargetTeam>
}
