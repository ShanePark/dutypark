package com.tistory.shanepark.dutypark.schedule.timeextract.domain

data class ScheduleTimeExtractionResponse(
    val result: Boolean = false,
    val hasTime: Boolean = false,
    val dateTime: String? = null,
    val content: String? = null,
) {
}
