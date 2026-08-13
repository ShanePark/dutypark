package com.tistory.shanepark.dutypark.schedule.timeparsing.service

import com.tistory.shanepark.dutypark.consent.service.AiScheduleParsingConsentService
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
import org.mockito.Mockito.lenient
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

    @Mock
    lateinit var aiScheduleParsingConsentService: AiScheduleParsingConsentService

    lateinit var queueManager: ScheduleTimeParsingQueueManager

    @BeforeEach
    fun setUp() {
        queueManager = ScheduleTimeParsingQueueManager(
            worker = worker,
            scheduleRepository = scheduleRepository,
            aiScheduleParsingConsentService = aiScheduleParsingConsentService,
            geminiApiKey = "GEMINI_KEY",
            rpmLimit = 30,
            rpdLimit = 14400,
        )
        lenient().`when`(aiScheduleParsingConsentService.hasCurrentConsent(any())).thenReturn(true)
    }

    @AfterEach
    fun tearDown() {
        queueManager.shutdown()
    }

    @Test
    fun `init should load WAIT schedules into queue`() {
        val schedules = listOf(
            makeSchedule(),
            makeSchedule(),
        )
        `when`(scheduleRepository.findAllByParsingTimeStatus(WAIT)).thenReturn(schedules)

        queueManager.init()

        assertEquals(2, queueManager.queueSize())
        verify(scheduleRepository, times(1)).findAllByParsingTimeStatus(WAIT)
    }

    @Test
    fun `init reclassifies WAIT schedules without owner consent as SKIP`() {
        val consented = makeSchedule(memberId = 1L)
        val nonConsented = makeSchedule(memberId = 2L)
        whenever(scheduleRepository.findAllByParsingTimeStatus(WAIT)).thenReturn(listOf(consented, nonConsented))
        whenever(aiScheduleParsingConsentService.hasCurrentConsent(1L)).thenReturn(true)
        whenever(aiScheduleParsingConsentService.hasCurrentConsent(2L)).thenReturn(false)
        whenever(
            scheduleRepository.updateParsingStatusIfCurrent(
                nonConsented.id,
                nonConsented.parsingGeneration,
                WAIT,
                ParsingTimeStatus.SKIP,
            )
        ).thenReturn(1)

        queueManager.init()

        assertEquals(1, queueManager.queueSize())
        assertEquals(ParsingTimeStatus.SKIP, nonConsented.parsingTimeStatus)
        verify(scheduleRepository).updateParsingStatusIfCurrent(
            nonConsented.id,
            nonConsented.parsingGeneration,
            WAIT,
            ParsingTimeStatus.SKIP,
        )
    }

    @Test
    fun `addTask should add only WAIT status tasks to queue`() {
        val waitSchedule = makeSchedule()
        val nonWaitSchedule = makeSchedule(PARSED)

        queueManager.addTask(waitSchedule)
        queueManager.addTask(nonWaitSchedule)

        assertEquals(1, queueManager.queueSize())
    }

    @Test
    fun `addTask inside a transaction enqueues only after commit`() {
        val schedule = makeSchedule()
        TransactionSynchronizationManager.initSynchronization()
        TransactionSynchronizationManager.setActualTransactionActive(true)

        try {
            queueManager.addTask(schedule)

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
        val schedule = makeSchedule()
        TransactionSynchronizationManager.initSynchronization()
        TransactionSynchronizationManager.setActualTransactionActive(true)

        try {
            queueManager.addTask(schedule)
            TransactionSynchronizationManager.getSynchronizations().forEach {
                it.afterCompletion(org.springframework.transaction.support.TransactionSynchronization.STATUS_ROLLED_BACK)
            }

            assertEquals(0, queueManager.queueSize())
        } finally {
            TransactionSynchronizationManager.setActualTransactionActive(false)
            TransactionSynchronizationManager.clearSynchronization()
        }
    }

    @ParameterizedTest
    @ValueSource(strings = ["", "EMPTY"])
    fun `missing API key disables startup recovery and new tasks`(apiKey: String) {
        queueManager.shutdown()
        queueManager = ScheduleTimeParsingQueueManager(
            worker = worker,
            scheduleRepository = scheduleRepository,
            aiScheduleParsingConsentService = aiScheduleParsingConsentService,
            geminiApiKey = apiKey,
            rpmLimit = 30,
            rpdLimit = 14400,
        )
        val schedule = makeSchedule()

        queueManager.init()
        queueManager.addTask(schedule)

        assertEquals(0, queueManager.queueSize())
        verify(scheduleRepository, never()).findAllByParsingTimeStatus(WAIT)
    }

    @Test
    fun `shutdown rejects new in-memory tasks and leaves schedule in WAIT`() {
        val schedule = makeSchedule()

        queueManager.shutdown()
        queueManager.addTask(schedule)

        assertEquals(0, queueManager.queueSize())
        assertEquals(WAIT, schedule.parsingTimeStatus)
    }

    @Test
    fun `unexpected worker failure does not prevent the next queued task`() {
        val first = makeSchedule()
        val second = makeSchedule()
        whenever(worker.run(any()))
            .thenThrow(RuntimeException("temporary repository failure"))
            .thenReturn(false)
        queueManager.addTask(first)
        queueManager.addTask(second)

        ReflectionTestUtils.invokeMethod<Unit>(queueManager, "run")
        ReflectionTestUtils.invokeMethod<Unit>(queueManager, "run")

        verify(worker, times(3)).run(any())
        assertEquals(0, queueManager.queueSize())
    }

    @Test
    fun `shutdown leaves already queued tasks untouched for next startup recovery`() {
        queueManager.addTask(makeSchedule())
        queueManager.addTask(makeSchedule())

        queueManager.shutdown()
        ReflectionTestUtils.invokeMethod<Unit>(queueManager, "run")

        verify(worker, never()).run(any())
        assertEquals(2, queueManager.queueSize())
    }

    private fun makeSchedule(
        parsingTimeStatus: ParsingTimeStatus = WAIT,
        memberId: Long = 1L,
    ): Schedule {
        val member = Member("")
        ReflectionTestUtils.setField(member, "id", memberId)
        val schedule = Schedule(member = member, content = "", startDateTime = fixedDateTime, endDateTime = fixedDateTime)
        schedule.parsingTimeStatus = parsingTimeStatus
        return schedule
    }

}
