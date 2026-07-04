package com.tistory.shanepark.dutypark.duty.domain.dto

import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Pattern
import jakarta.validation.constraints.Size
import org.springframework.validation.annotation.Validated

@Validated
data class DutyTypeCreateDto(
    val teamId: Long,
    @field:Size(min = 1, max = 10, message = "dutyType.name.length")
    @field:NotBlank(message = "dutyType.name.required")
    val name: String,
    @field:Pattern(regexp = "^#[0-9a-fA-F]{6}$", message = "dutyType.color.invalid")
    val color: String,
)
