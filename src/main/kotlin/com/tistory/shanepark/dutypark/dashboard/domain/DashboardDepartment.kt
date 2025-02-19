package com.tistory.shanepark.dutypark.dashboard.domain

import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeDto
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto

data class DashboardDepartment(
    val department: DepartmentDto,
    val members: Map<DutyTypeDto, List<MemberDto>>
)
