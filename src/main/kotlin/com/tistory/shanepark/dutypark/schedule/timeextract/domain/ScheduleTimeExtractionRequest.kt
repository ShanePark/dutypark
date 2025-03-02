package com.tistory.shanepark.dutypark.schedule.timeextract.domain

import java.time.LocalDate

data class ScheduleTimeExtractionRequest(
    val date: LocalDate,
    val content: String,
) {
}
