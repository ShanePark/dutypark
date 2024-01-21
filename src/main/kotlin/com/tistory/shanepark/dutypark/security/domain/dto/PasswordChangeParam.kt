package com.tistory.shanepark.dutypark.security.domain.dto

data class PasswordChangeParam(
    val memberId: Long,
    val currentPassword: String,
    val newPassword: String
)
