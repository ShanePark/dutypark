package com.tistory.shanepark.dutypark.security.domain.dto

data class PasswordChangeDto(
    val memberId: Long,
    val currentPassword: String?,
    val newPassword: String
)
