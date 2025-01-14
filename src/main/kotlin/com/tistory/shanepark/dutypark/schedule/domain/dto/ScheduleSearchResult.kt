package com.tistory.shanepark.dutypark.schedule.domain.dto

import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import java.time.LocalDateTime

data class ScheduleSearchResult(
    val content: String,
    val startDateTime: LocalDateTime,
    val endDateTime: LocalDateTime,
    val visibility: String,
    val isTagged: Boolean,
    val author: String
) {
    companion object {
        fun of(schedule: Schedule): ScheduleSearchResult {
            return ScheduleSearchResult(
                content = schedule.content,
                startDateTime = schedule.startDateTime,
                endDateTime = schedule.endDateTime,
                visibility = schedule.visibility.name,
                isTagged = schedule.tags.isNotEmpty(),
                author = schedule.member.name
            )
        }
    }
}
