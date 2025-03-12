package com.tistory.shanepark.dutypark.department.domain.dto

import java.time.YearMonth

data class MyTeamSummary(
    val yearMonth: YearMonth,
    val department: DepartmentDto? = null,
    val teamDays: List<TeamDay> = emptyList(),
)
