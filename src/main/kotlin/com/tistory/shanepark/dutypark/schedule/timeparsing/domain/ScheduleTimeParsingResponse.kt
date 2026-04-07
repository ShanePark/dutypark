package com.tistory.shanepark.dutypark.schedule.timeparsing.domain

data class ScheduleTimeParsingResponse(
    val result: Boolean = false,
    val hasTime: Boolean = false,
    val startDateTime: String? = null,
    val endDateTime: String? = null,
    val content: String? = null,
    val errorMessage: String? = null,
    val rawResponse: String? = null,
) {
    fun toLogMessage(request: ScheduleTimeParsingRequest): String {
        return "date=${request.date}, content='${request.content}' -> '${contentForLog()}', " +
                "time=${parsedTimeForLog()}, hasTime=$hasTime, result=$result"
    }

    private fun contentForLog(): String {
        return content ?: "<null>"
    }

    private fun parsedTimeForLog(): String {
        return when {
            startDateTime == null && endDateTime == null -> "-"
            startDateTime == null -> endDateTime!!
            endDateTime == null || startDateTime == endDateTime -> startDateTime
            else -> "$startDateTime ~ $endDateTime"
        }
    }
}
