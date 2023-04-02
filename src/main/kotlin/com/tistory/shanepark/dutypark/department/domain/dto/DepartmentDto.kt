package com.tistory.shanepark.dutypark.department.domain.dto

import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeDto

data class DepartmentDto(
    val id: Long,
    val name: String,
    val dutyTypes: List<DutyTypeDto>,
)
