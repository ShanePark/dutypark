package com.tistory.shanepark.dutypark.security.domain.dto

import jakarta.validation.constraints.NotBlank
import org.hibernate.validator.constraints.Length
import org.springframework.validation.annotation.Validated

@Validated
data class PasswordChangeDto(
    val memberId: Long,
    val currentPassword: String?,
    @field:NotBlank
    @field:Length(min = 8, max = 20)
    val newPassword: String
)
