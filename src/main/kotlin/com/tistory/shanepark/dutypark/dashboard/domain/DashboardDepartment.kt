package com.tistory.shanepark.dutypark.dashboard.domain

import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeDto

data class DashboardDepartment(
    val department: DepartmentDto?,
    val groups: List<DutyByShift>,
)

data class DutyByShift(
    val dutyType: DutyTypeDto,
    val members: List<DashboardSimpleMember>
)

data class DashboardSimpleMember(
    val id: Long?,
    val name: String,
)
