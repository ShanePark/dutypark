package com.tistory.shanepark.dutypark.schedule.timeparsing.domain

import java.time.LocalDate

data class ScheduleTimeParsingRequest(
    val date: LocalDate,
    val content: String,
)
