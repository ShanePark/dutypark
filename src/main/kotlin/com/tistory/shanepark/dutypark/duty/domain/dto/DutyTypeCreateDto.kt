package com.tistory.shanepark.dutypark.duty.domain.dto

import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Pattern
import jakarta.validation.constraints.Size
import org.springframework.validation.annotation.Validated

@Validated
data class DutyTypeCreateDto(
    val teamId: Long,
    @field:Size(min = 1, max = 10, message = "근무명은 1자 이상 10자 이하로 입력해주세요.")
    @field:NotBlank
    val name: String,
    @field:Pattern(regexp = "^#[0-9a-fA-F]{6}$", message = "올바른 색상 형식이 아닙니다.")
    val color: String,
)
