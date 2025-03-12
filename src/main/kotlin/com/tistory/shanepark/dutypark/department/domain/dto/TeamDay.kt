package com.tistory.shanepark.dutypark.department.domain.dto

data class TeamDay(
    val year: Int,
    val month: Int,
    val day: Int,
    val deptSchedules: List<String> = emptyList(), // TODO: implementation
)
