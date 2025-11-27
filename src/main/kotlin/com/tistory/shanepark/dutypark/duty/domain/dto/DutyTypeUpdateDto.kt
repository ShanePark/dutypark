package com.tistory.shanepark.dutypark.duty.domain.dto

import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Pattern
import jakarta.validation.constraints.Size

data class DutyTypeUpdateDto(
    val id: Long,
    @field:Size(min = 1, max = 10)
    @field:NotBlank
    val name: String,
    @field:Pattern(regexp = "^#[0-9a-fA-F]{6}$", message = "올바른 색상 형식이 아닙니다.")
    val color: String,
)
