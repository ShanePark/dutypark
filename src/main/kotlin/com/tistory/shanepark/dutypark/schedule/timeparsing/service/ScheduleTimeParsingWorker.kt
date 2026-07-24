package com.tistory.shanepark.dutypark.schedule.timeparsing.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackNotifier
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.domain.enums.ParsingTimeStatus
import com.tistory.shanepark.dutypark.schedule.domain.enums.ParsingTimeStatus.*
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.schedule.timeparsing.domain.ScheduleTimeIndicator
import com.tistory.shanepark.dutypark.schedule.timeparsing.domain.ScheduleTimeParsingRequest
import com.tistory.shanepark.dutypark.schedule.timeparsing.domain.ScheduleTimeParsingResponse
import com.tistory.shanepark.dutypark.schedule.timeparsing.domain.ScheduleTimeParsingTask
import net.gpedro.integrations.slack.SlackAttachment
import net.gpedro.integrations.slack.SlackField
import net.gpedro.integrations.slack.SlackMessage
import org.springframework.stereotype.Service
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeParseException

@Service
class ScheduleTimeParsingWorker(
    private val scheduleTimeParsingService: ScheduleTimeParsingService,
    private val scheduleRepository: ScheduleRepository,
    private val slackNotifier: SlackNotifier,
) {
    private val log = logger()
    fun run(task: ScheduleTimeParsingTask): Boolean {
        val schedule = findCurrentSchedule(task) ?: return false

        if (alreadyHaveTimeInfo(task, schedule)) return false
        if (noTimeRelatedText(task, schedule)) return false

        val request = ScheduleTimeParsingRequest(
            date = LocalDate.of(
                schedule.startDateTime.year,
                schedule.startDateTime.monthValue,
                schedule.startDateTime.dayOfMonth,
            ),
            content = schedule.content
        )

        val response: ScheduleTimeParsingResponse
        try {
            response = scheduleTimeParsingService.parseScheduleTime(request)
        } catch (e: Exception) {
            if (e.isInterruption()) {
                Thread.currentThread().interrupt()
                log.info("AI parsing interrupted during shutdown: scheduleId={}", task.scheduleId)
                return false
            }
            log.error("AI parsing failed for schedule {}: {}", task.scheduleId, e.message, e)
            if (updateStatusIfCurrent(task, schedule, FAILED)) {
                notifyLlmError(
                    scheduleId = task.scheduleId.toString(),
                    content = request.content,
                    errorMessage = e.message,
                    rawResponse = null,
                    stackTrace = e.stackTraceToString()
                )
            }
            return true
        }

        if (responseFail(task, response, schedule)) return true
        if (haveNoTimeInfo(task, response, schedule)) return true

        try {
            val parsedStart = LocalDateTime.parse(response.startDateTime.toString())
            val parsedEnd = LocalDateTime.parse(response.endDateTime.toString())
            if (parsedStart.toLocalDate() != request.date ||
                parsedEnd.toLocalDate() != request.date ||
                parsedEnd.isBefore(parsedStart)
            ) {
                log.warn("Rejected out-of-range parsed dateTime: {}", response)
                updateStatusIfCurrent(task, schedule, FAILED)
                return true
            }
            applyParsingResultIfCurrent(
                task = task,
                schedule = schedule,
                parsedStart = parsedStart,
                parsedEnd = parsedEnd,
                contentWithoutTime = response.content ?: "",
            )
        } catch (e: DateTimeParseException) {
            log.warn("Failed to parse dateTime: {}", response)
            updateStatusIfCurrent(task, schedule, FAILED)
        }
        return true
    }

    private fun Throwable.isInterruption(): Boolean {
        var current: Throwable? = this
        while (current != null) {
            if (current is InterruptedException) return true
            current = current.cause
        }
        return false
    }

    private fun findCurrentSchedule(task: ScheduleTimeParsingTask): Schedule? {
        val schedule = scheduleRepository.findById(task.scheduleId).orElse(null) ?: return null
        if (task.isExpired(schedule) || schedule.parsingTimeStatus != WAIT) return null
        return schedule
    }

    private fun haveNoTimeInfo(
        task: ScheduleTimeParsingTask,
        response: ScheduleTimeParsingResponse,
        schedule: Schedule
    ): Boolean {
        if (response.hasTime) {
            return false
        }
        updateStatusIfCurrent(task, schedule, NO_TIME_INFO)
        return true
    }

    private fun responseFail(
        task: ScheduleTimeParsingTask,
        response: ScheduleTimeParsingResponse,
        schedule: Schedule
    ): Boolean {
        if (response.result) {
            return false
        }
        val updated = updateStatusIfCurrent(task, schedule, FAILED)

        if (updated && (response.errorMessage != null || response.rawResponse != null)) {
            notifyLlmError(
                scheduleId = schedule.id.toString(),
                content = schedule.content,
                errorMessage = response.errorMessage,
                rawResponse = response.rawResponse,
                stackTrace = null
            )
        }
        return true
    }

    private fun alreadyHaveTimeInfo(task: ScheduleTimeParsingTask, schedule: Schedule): Boolean {
        if (schedule.hasTimeInfo() || schedule.startDateTime != schedule.endDateTime) {
            updateStatusIfCurrent(task, schedule, ALREADY_HAVE_TIME_INFO)
            return true
        }
        return false
    }

    private fun noTimeRelatedText(task: ScheduleTimeParsingTask, schedule: Schedule): Boolean {
        if (ScheduleTimeIndicator.existsIn(schedule.content)) {
            return false
        }

        updateStatusIfCurrent(task, schedule, NO_TIME_INFO)
        return true
    }

    private fun updateStatusIfCurrent(
        task: ScheduleTimeParsingTask,
        schedule: Schedule,
        newStatus: ParsingTimeStatus,
    ): Boolean {
        val updated = scheduleRepository.updateParsingStatusIfCurrent(
            id = task.scheduleId,
            parsingGeneration = task.parsingGeneration,
            expectedStatus = WAIT,
            newStatus = newStatus,
        ) == 1
        if (updated) {
            schedule.parsingTimeStatus = newStatus
        }
        return updated
    }

    private fun applyParsingResultIfCurrent(
        task: ScheduleTimeParsingTask,
        schedule: Schedule,
        parsedStart: LocalDateTime,
        parsedEnd: LocalDateTime,
        contentWithoutTime: String,
    ): Boolean {
        val updated = scheduleRepository.applyParsingResultIfCurrent(
            id = task.scheduleId,
            parsingGeneration = task.parsingGeneration,
            expectedStatus = WAIT,
            newStatus = PARSED,
            startDateTime = parsedStart,
            endDateTime = parsedEnd,
            contentWithoutTime = contentWithoutTime,
        ) == 1
        if (updated) {
            schedule.parsingTimeStatus = PARSED
            schedule.startDateTime = parsedStart
            schedule.endDateTime = parsedEnd
            schedule.contentWithoutTime = contentWithoutTime
        }
        return updated
    }

    private fun notifyLlmError(
        scheduleId: String,
        content: String,
        errorMessage: String?,
        rawResponse: String?,
        stackTrace: String?
    ) {
        val slackAttachment = SlackAttachment()
        slackAttachment.setFallback("LLM Parsing Error")
        slackAttachment.setColor("danger")
        slackAttachment.setTitle("LLM Time Parsing Failed")
        stackTrace?.let { slackAttachment.setText(it) }

        val fields = mutableListOf(
            SlackField().setTitle("Schedule ID").setValue(scheduleId),
            SlackField().setTitle("Content").setValue(content),
            SlackField().setTitle("Time").setValue(LocalDateTime.now().toString()),
        )
        errorMessage?.let { fields.add(SlackField().setTitle("Error Message").setValue(it)) }
        rawResponse?.let { fields.add(SlackField().setTitle("LLM Response").setValue(it)) }
        slackAttachment.setFields(fields)

        val slackMessage = SlackMessage()
        slackMessage.setAttachments(listOf(slackAttachment))
        slackMessage.setIcon(":warning:")
        slackMessage.setText("LLM Parsing Error Detected")
        slackMessage.setUsername("DutyPark")

        slackNotifier.call(slackMessage)
    }

}
