package com.tistory.shanepark.dutypark.team.domain.dto

data class TeamDay(
    val year: Int,
    val month: Int,
    val day: Int,
    val teamSchedule: List<String> = emptyList(), // TODO: implementation
)
