package com.tistory.shanepark.dutypark.team.domain.dto

import java.time.YearMonth

data class MyTeamSummary(
    val yearMonth: YearMonth,
    val team: TeamDto? = null,
    val teamDays: List<TeamDay> = emptyList(),
    val isTeamManager: Boolean = false,
)
