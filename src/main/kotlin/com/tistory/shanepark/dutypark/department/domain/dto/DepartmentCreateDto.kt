package com.tistory.shanepark.dutypark.department.domain.dto

import jakarta.validation.constraints.NotEmpty
import jakarta.validation.constraints.Size

data class DepartmentCreateDto(
    @field:Size(min = 2, max = 20)
    @field:NotEmpty
    val name: String,
    val description: String,
)
