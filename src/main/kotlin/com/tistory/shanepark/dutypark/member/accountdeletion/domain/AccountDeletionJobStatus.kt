package com.tistory.shanepark.dutypark.member.accountdeletion.domain

enum class AccountDeletionJobStatus {
    PENDING,
    PROCESSING,
    RETRY_WAIT,
    COMPLETED,
    FAILED,
}
