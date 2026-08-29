package com.tistory.shanepark.dutypark.member.accountdeletion.worker

/** Identifies one worker lease so a stale worker cannot finish a newer attempt. */
data class AccountDeletionClaim(
    val jobId: Long,
    val leaseToken: String,
)
