package com.tistory.shanepark.dutypark.schedule.timeparsing.service

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.domain.enums.ParsingTimeStatus
import com.tistory.shanepark.dutypark.schedule.domain.enums.ParsingTimeStatus.PARSED
import com.tistory.shanepark.dutypark.schedule.domain.enums.ParsingTimeStatus.WAIT
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource
import org.mockito.Mock
import org.mockito.Mockito.`when`
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.any
import org.mockito.kotlin.never
import org.mockito.kotlin.times
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.springframework.test.util.ReflectionTestUtils
import org.springframework.transaction.support.TransactionSynchronizationManager
import java.time.LocalDateTime

@ExtendWith(MockitoExtension::class)
class ScheduleTimeParsingQueueManagerTest {

    private val fixedDateTime = LocalDateTime.of(2025, 1, 15, 12, 0, 0)

    @Mock
    lateinit var worker: ScheduleTimeParsingWorker

    @Mock
    lateinit var scheduleRepository: ScheduleRepository

    lateinit var queueManager: ScheduleTimeParsingQueueManager

    @BeforeEach
    fun setUp() {
        queueManager = ScheduleTimeParsingQueueManager(
            worker = worker,
            scheduleRepository = scheduleRepository,
            geminiApiKey = "GEMINI_KEY",
            rpmLimit = 30,
            rpdLimit = 14400,
        )
    }

    @AfterEach
    fun tearDown() {
        queueManager.shutdown()
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

    @Test
    fun `addTask inside a transaction enqueues only after commit`() {
        // Given
        val schedule = makeSchedule()
        TransactionSynchronizationManager.initSynchronization()
        TransactionSynchronizationManager.setActualTransactionActive(true)

        try {
            // When
            queueManager.addTask(schedule)

            // Then
            assertEquals(0, queueManager.queueSize())

            TransactionSynchronizationManager.getSynchronizations().forEach { it.afterCommit() }
            assertEquals(1, queueManager.queueSize())
        } finally {
            TransactionSynchronizationManager.setActualTransactionActive(false)
            TransactionSynchronizationManager.clearSynchronization()
        }
    }

    @Test
    fun `rolled back transaction does not enqueue task`() {
        // Given
        val schedule = makeSchedule()
        TransactionSynchronizationManager.initSynchronization()
        TransactionSynchronizationManager.setActualTransactionActive(true)

        try {
            // When
            queueManager.addTask(schedule)
            TransactionSynchronizationManager.getSynchronizations().forEach {
                it.afterCompletion(org.springframework.transaction.support.TransactionSynchronization.STATUS_ROLLED_BACK)
            }

            // Then
            assertEquals(0, queueManager.queueSize())
        } finally {
            TransactionSynchronizationManager.setActualTransactionActive(false)
            TransactionSynchronizationManager.clearSynchronization()
        }
    }

    @ParameterizedTest
    @ValueSource(strings = ["", "EMPTY"])
    fun `missing API key disables startup recovery and new tasks`(apiKey: String) {
        // Given
        queueManager.shutdown()
        queueManager = ScheduleTimeParsingQueueManager(
            worker = worker,
            scheduleRepository = scheduleRepository,
            geminiApiKey = apiKey,
            rpmLimit = 30,
            rpdLimit = 14400,
        )
        val schedule = makeSchedule()

        // When
        queueManager.init()
        queueManager.addTask(schedule)

        // Then
        assertEquals(0, queueManager.queueSize())
        verify(scheduleRepository, never()).findAllByParsingTimeStatus(WAIT)
    }

    @Test
    fun `shutdown rejects new in-memory tasks and leaves schedule in WAIT`() {
        // Given
        val schedule = makeSchedule()

        // When
        queueManager.shutdown()
        queueManager.addTask(schedule)

        // Then
        assertEquals(0, queueManager.queueSize())
        assertEquals(WAIT, schedule.parsingTimeStatus)
    }

    @Test
    fun `unexpected worker failure does not prevent the next queued task`() {
        // Given
        val first = makeSchedule()
        val second = makeSchedule()
        whenever(worker.run(any()))
            .thenThrow(RuntimeException("temporary repository failure"))
            .thenReturn(false)
        queueManager.addTask(first)
        queueManager.addTask(second)

        // When
        ReflectionTestUtils.invokeMethod<Unit>(queueManager, "run")
        ReflectionTestUtils.invokeMethod<Unit>(queueManager, "run")

        // Then
        verify(worker, times(3)).run(any())
        assertEquals(0, queueManager.queueSize())
    }

    @Test
    fun `shutdown leaves already queued tasks untouched for next startup recovery`() {
        // Given
        queueManager.addTask(makeSchedule())
        queueManager.addTask(makeSchedule())

        // When
        queueManager.shutdown()
        ReflectionTestUtils.invokeMethod<Unit>(queueManager, "run")

        // Then
        verify(worker, never()).run(any())
        assertEquals(2, queueManager.queueSize())
    }

    private fun makeSchedule(parsingTimeStatus: ParsingTimeStatus = WAIT): Schedule {
        val member = Member("")
        val schedule = Schedule(member = member, content = "", startDateTime = fixedDateTime, endDateTime = fixedDateTime)
        schedule.parsingTimeStatus = parsingTimeStatus
        return schedule
    }

}
