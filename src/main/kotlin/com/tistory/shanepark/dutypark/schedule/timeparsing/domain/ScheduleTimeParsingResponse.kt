package com.tistory.shanepark.dutypark.schedule.timeparsing.domain

data class ScheduleTimeParsingResponse(
    val result: Boolean = false,
    val hasTime: Boolean = false,
    val dateTime: String? = null,
    val content: String? = null,
)
