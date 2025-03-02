package com.tistory.shanepark.dutypark.schedule.timeparsing.service

import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.domain.enums.ParsingTimeStatus.*
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.schedule.timeparsing.domain.ScheduleTimeParsingRequest
import com.tistory.shanepark.dutypark.schedule.timeparsing.domain.ScheduleTimeParsingResponse
import com.tistory.shanepark.dutypark.schedule.timeparsing.domain.ScheduleTimeParsingTask
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeParseException

/**
 * Do not use @Transaction dirty checking since it will be on another thread.
 */
@Service
class ScheduleTimeParsingWorker(
    private val scheduleTimeParsingService: ScheduleTimeParsingService,
    private val scheduleRepository: ScheduleRepository,
) {
    private val log: Logger = LoggerFactory.getLogger(ScheduleTimeParsingWorker::class.java)

    fun run(task: ScheduleTimeParsingTask) {
        val scheduleOption = scheduleRepository.findById(task.scheduleId)
        if (scheduleOption.isEmpty) {
            log.info("Schedule not found. maybe already deleted. scheduleId: ${task.scheduleId}")
            return
        }
        val schedule = scheduleOption.get()
        if (task.isExpired(schedule)) {
            log.info("Schedule is updated, skip parsing. scheduleId: ${task.scheduleId}")
            return
        }

        if (alreadyHaveTimeInfo(schedule)) return

        val request = ScheduleTimeParsingRequest(
            date = LocalDate.of(
                schedule.startDateTime.year,
                schedule.startDateTime.monthValue,
                schedule.startDateTime.dayOfMonth,
            ),
            content = schedule.content
        )
        val response = scheduleTimeParsingService.parseScheduleTime(request)

        if (responseFail(response, schedule)) return
        if (haveNoTimeInfo(response, schedule)) return

        try {
            val parsed: LocalDateTime = LocalDateTime.parse(response.dateTime.toString())
            schedule.parsingTimeStatus = PARSED
            schedule.startDateTime = parsed
            schedule.contentWithoutTime = response.content ?: ""
            scheduleRepository.save(schedule)
        } catch (e: DateTimeParseException) {
            log.warn("Failed to parse dateTime: $response")
            schedule.parsingTimeStatus = FAILED
            scheduleRepository.save(schedule)
        }
    }

    private fun haveNoTimeInfo(
        response: ScheduleTimeParsingResponse,
        schedule: Schedule
    ): Boolean {
        if (response.hasTime) {
            return false
        }
        schedule.parsingTimeStatus = NO_TIME_INFO
        scheduleRepository.save(schedule)
        return true
    }

    private fun responseFail(
        response: ScheduleTimeParsingResponse,
        schedule: Schedule
    ): Boolean {
        if (response.result) {
            return false
        }
        schedule.parsingTimeStatus = FAILED
        scheduleRepository.save(schedule)
        return true
    }

    private fun alreadyHaveTimeInfo(schedule: Schedule): Boolean {
        if (schedule.hasTimeInfo()) {
            schedule.parsingTimeStatus = ALREADY_HAVE_TIME_INFO
            scheduleRepository.save(schedule)
            return true
        }
        return false
    }

}
