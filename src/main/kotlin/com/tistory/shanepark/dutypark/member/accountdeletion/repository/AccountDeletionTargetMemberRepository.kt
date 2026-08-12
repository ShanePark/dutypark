package com.tistory.shanepark.dutypark.member.accountdeletion.repository

import com.tistory.shanepark.dutypark.member.accountdeletion.domain.AccountDeletionTargetMember
import org.springframework.data.jpa.repository.JpaRepository

interface AccountDeletionTargetMemberRepository : JpaRepository<AccountDeletionTargetMember, Long> {
    fun findAllByJobId(jobId: Long): List<AccountDeletionTargetMember>
}
