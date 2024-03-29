package com.tistory.shanepark.dutypark.duty.domain.dto

import com.tistory.shanepark.dutypark.duty.enums.Color
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size

data class DutyTypeUpdateDto(
    val id: Long,
    @field:Size(min = 1, max = 12)
    @field:NotBlank
    val name: String,
    val color: Color,
)
