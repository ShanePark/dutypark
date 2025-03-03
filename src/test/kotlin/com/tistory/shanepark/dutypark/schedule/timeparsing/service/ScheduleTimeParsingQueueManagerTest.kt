package com.tistory.shanepark.dutypark.schedule.timeparsing.service

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.domain.enums.ParsingTimeStatus
import com.tistory.shanepark.dutypark.schedule.domain.enums.ParsingTimeStatus.PARSED
import com.tistory.shanepark.dutypark.schedule.domain.enums.ParsingTimeStatus.WAIT
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.Mockito.`when`
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.times
import org.mockito.kotlin.verify
import java.time.LocalDateTime

@ExtendWith(MockitoExtension::class)
class ScheduleTimeParsingQueueManagerTest {

    @Mock
    lateinit var worker: ScheduleTimeParsingWorker

    @Mock
    lateinit var scheduleRepository: ScheduleRepository

    @InjectMocks
    lateinit var queueManager: ScheduleTimeParsingQueueManager

    @BeforeEach
    fun setUp() {
        queueManager = ScheduleTimeParsingQueueManager(worker, scheduleRepository)
    }

    @Test
    fun `init should load WAIT schedules into queue`() {
        // Given
        val schedules = listOf(
            makeSchedule(),
            makeSchedule(),
        )
        `when`(scheduleRepository.findAllByParsingTimeStatus(WAIT)).thenReturn(schedules)

        // When
        queueManager.init()

        // Then
        assertEquals(2, queueManager.queueSize())
        verify(scheduleRepository, times(1)).findAllByParsingTimeStatus(WAIT)
    }

    @Test
    fun `addTask should add only WAIT status tasks to queue`() {
        // Given
        val waitSchedule = makeSchedule()
        val nonWaitSchedule = makeSchedule(PARSED)

        // When
        queueManager.addTask(waitSchedule)
        queueManager.addTask(nonWaitSchedule)

        // Then
        assertEquals(1, queueManager.queueSize())
    }

    private fun makeSchedule(parsingTimeStatus: ParsingTimeStatus = WAIT): Schedule {
        val now = LocalDateTime.now()
        val member = Member("")
        val schedule = Schedule(member = member, content = "", startDateTime = now, endDateTime = now)
        schedule.parsingTimeStatus = parsingTimeStatus
        return schedule
    }

}
