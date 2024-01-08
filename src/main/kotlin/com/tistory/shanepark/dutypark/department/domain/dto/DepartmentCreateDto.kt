package com.tistory.shanepark.dutypark.department.domain.dto

import jakarta.validation.constraints.NotEmpty
import jakarta.validation.constraints.Size

data class DepartmentCreateDto(
    @field:Size(min = 2, max = 20)
    @field:NotEmpty
    val name: String,
    @field:Size(min = 0, max = 50, message = "50자 이하로 입력해주세요.")
    val description: String,
)
