package com.tistory.shanepark.dutypark.duty.domain.dto

import com.tistory.shanepark.dutypark.duty.enums.Color
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import org.springframework.validation.annotation.Validated

@Validated
data class DutyTypeCreateDto(
    val departmentId: Long,
    @field:Size(min = 1, max = 10, message = "근무명은 1자 이상 10자 이하로 입력해주세요.")
    @field:NotBlank
    val name: String,
    val color: Color,
)
