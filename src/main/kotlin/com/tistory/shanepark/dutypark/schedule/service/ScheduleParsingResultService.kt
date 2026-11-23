package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.schedule.domain.enums.ParsingTimeStatus
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDateTime
import java.util.UUID

@Service
class ScheduleParsingResultService(
    private val scheduleRepository: ScheduleRepository,
    private val revisionService: ScheduleRevisionService,
) {
    @Transactional
    fun applyParsingResultIfCurrent(
        id: UUID,
        parsingGeneration: UUID,
        expectedStatus: ParsingTimeStatus,
        newStatus: ParsingTimeStatus,
        startDateTime: LocalDateTime,
        endDateTime: LocalDateTime,
        contentWithoutTime: String,
    ): Int {
        val schedule = scheduleRepository.findByIdForUpdate(id).orElse(null) ?: return 0
        if (schedule.parsingGeneration != parsingGeneration || schedule.parsingTimeStatus != expectedStatus) return 0
        val before = revisionService.capture(schedule)
        schedule.parsingTimeStatus = newStatus
        schedule.startDateTime = startDateTime
        schedule.endDateTime = endDateTime
        schedule.contentWithoutTime = contentWithoutTime
        revisionService.recordChange(schedule, before, null, "SYSTEM")
        return 1
    }
}
