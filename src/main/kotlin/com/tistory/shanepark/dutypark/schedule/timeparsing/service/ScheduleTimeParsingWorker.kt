package com.tistory.shanepark.dutypark.schedule.timeparsing.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackNotifier
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.domain.enums.ParsingTimeStatus.*
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
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
    private val timePattern = Regex("""\d+|한|두|세|네|다섯|여섯|일곱|여덟|아홉|열|열한|열두""")

    fun run(task: ScheduleTimeParsingTask) {
        val scheduleOption = scheduleRepository.findById(task.scheduleId)
        if (scheduleOption.isEmpty) {
            return
        }
        val schedule = scheduleOption.get()
        if (task.isExpired(schedule)) {
            return
        }

        if (alreadyHaveTimeInfo(schedule)) return
        if (noTimeRelatedText(schedule)) return

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
            log.error("AI parsing failed for schedule {}: {}", task.scheduleId, e.message, e)
            schedule.parsingTimeStatus = FAILED
            scheduleRepository.save(schedule)
            notifyLlmError(
                scheduleId = task.scheduleId.toString(),
                content = request.content,
                errorMessage = e.message,
                rawResponse = null,
                stackTrace = e.stackTraceToString()
            )
            return
        }

        if (responseFail(response, schedule)) return
        if (haveNoTimeInfo(response, schedule)) return

        try {
            val parsedStart = LocalDateTime.parse(response.startDateTime.toString())
            val parsedEnd = LocalDateTime.parse(response.endDateTime.toString())
            schedule.parsingTimeStatus = PARSED
            schedule.startDateTime = parsedStart
            schedule.endDateTime = parsedEnd
            schedule.contentWithoutTime = response.content ?: ""

            // Do not use JPA dirty checking since it will be working on another thread.
            scheduleRepository.save(schedule)
        } catch (e: DateTimeParseException) {
            log.warn("Failed to parse dateTime: {}", response)
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

        if (response.errorMessage != null || response.rawResponse != null) {
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

    private fun alreadyHaveTimeInfo(schedule: Schedule): Boolean {
        if (schedule.hasTimeInfo() || schedule.startDateTime != schedule.endDateTime) {
            schedule.parsingTimeStatus = ALREADY_HAVE_TIME_INFO
            scheduleRepository.save(schedule)
            return true
        }
        return false
    }

    private fun noTimeRelatedText(schedule: Schedule): Boolean {
        if (timePattern.containsMatchIn(schedule.content)) {
            return false
        }

        schedule.parsingTimeStatus = NO_TIME_INFO
        scheduleRepository.save(schedule)
        return true
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
