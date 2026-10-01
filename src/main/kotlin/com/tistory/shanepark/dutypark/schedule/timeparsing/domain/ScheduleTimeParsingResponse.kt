package com.tistory.shanepark.dutypark.schedule.timeparsing.domain

import com.fasterxml.jackson.annotation.JsonIgnore
import com.tistory.shanepark.dutypark.common.logging.auditContext

data class ScheduleTimeParsingResponse(
    val result: Boolean = false,
    val hasTime: Boolean = false,
    val startDateTime: String? = null,
    val endDateTime: String? = null,
    val content: String? = null,
    val errorMessage: String? = null,
    val rawResponse: String? = null,
    @get:JsonIgnore
    val errorType: String? = null,
) {
    fun toLogMessage(
        request: ScheduleTimeParsingRequest,
        context: Map<String, Any?> = emptyMap(),
    ): String = auditContext(
        context + linkedMapOf(
            "date" to request.date,
            "contentBefore" to request.content,
            "contentAfter" to contentForLog(),
            "time" to parsedTimeForLog(),
            "hasTime" to hasTime,
            "result" to result,
            "errorType" to errorType,
            "rawResponse" to rawResponse,
        )
    )

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
