package com.tistory.shanepark.dutypark.duty.domain.dto

import com.tistory.shanepark.dutypark.duty.enums.Color
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size

data class DutyTypeCreateDto(
    val departmentId: Long,
    @field:Size(min = 1, max = 10)
    @field:NotBlank
    val name: String,
    val color: Color,
)
