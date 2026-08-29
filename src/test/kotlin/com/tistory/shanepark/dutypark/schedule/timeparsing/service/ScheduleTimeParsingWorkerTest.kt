import com.tistory.shanepark.dutypark.common.slack.notifier.SlackNotifier
import com.tistory.shanepark.dutypark.consent.service.AiScheduleParsingConsentService
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.domain.enums.ParsingTimeStatus
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.schedule.timeparsing.domain.ScheduleTimeParsingResponse
import com.tistory.shanepark.dutypark.schedule.timeparsing.domain.ScheduleTimeParsingTask
import com.tistory.shanepark.dutypark.schedule.timeparsing.service.ScheduleTimeParsingService
import com.tistory.shanepark.dutypark.schedule.timeparsing.service.ScheduleTimeParsingWorker
import net.gpedro.integrations.slack.SlackMessage
import net.gpedro.integrations.slack.SlackAttachment
import net.gpedro.integrations.slack.SlackField
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.EnumSource
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.Mockito.*
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.any
import org.mockito.kotlin.anyOrNull
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.whenever
import org.springframework.test.util.ReflectionTestUtils
import java.time.LocalDateTime
import java.util.*

@ExtendWith(MockitoExtension::class)
class ScheduleTimeParsingWorkerTest {

    @Mock
    lateinit var scheduleTimeParsingService: ScheduleTimeParsingService

    @Mock
    lateinit var scheduleRepository: ScheduleRepository

    @Mock
    lateinit var slackNotifier: SlackNotifier

    @Mock
    lateinit var aiScheduleParsingConsentService: AiScheduleParsingConsentService

    @InjectMocks
    lateinit var worker: ScheduleTimeParsingWorker

    @BeforeEach
    fun setUpAtomicUpdates() {
        lenient().whenever(aiScheduleParsingConsentService.hasCurrentConsent(any())).thenReturn(true)
        lenient().whenever(
            scheduleRepository.updateParsingStatusIfCurrent(any(), any(), any(), any())
        ).thenReturn(1)
        lenient().whenever(
            scheduleRepository.applyParsingResultIfCurrent(
                any(), any(), any(), any(), any(), any(), any()
            )
        ).thenReturn(1)
    }

    private fun createSchedule(content: String = "3시 회의"): Schedule {
        val randomDay = LocalDateTime.of(2025, 3, 3, 0, 0, 0, 0)
        val member = Member("")
        ReflectionTestUtils.setField(member, "id", 1L)
        val schedule = Schedule(member = member, content = content, startDateTime = randomDay, endDateTime = randomDay)
        return schedule
    }

    @Test
    fun `if schedule is already deleted, never run`() {
        val schedule = createSchedule()
        val task = ScheduleTimeParsingTask(schedule)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.empty())

        val aiAttempted = worker.run(task)

        assertThat(aiAttempted).isFalse()
        verify(scheduleRepository, never()).updateParsingStatusIfCurrent(any(), any(), any(), any())
        verify(scheduleRepository, never()).applyParsingResultIfCurrent(
            any(), any(), any(), any(), any(), any(), any()
        )
    }

    @Test
    fun `if the task snapshot no longer matches, skip`() {
        val schedule = createSchedule()
        val task = ScheduleTimeParsingTask(schedule)
        schedule.updateParsingInput(
            content = "수정된 일정",
            startDateTime = schedule.startDateTime,
            endDateTime = schedule.endDateTime,
        )
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))

        val aiAttempted = worker.run(task)

        assertThat(aiAttempted).isFalse()
        verify(scheduleRepository, never()).updateParsingStatusIfCurrent(any(), any(), any(), any())
        verify(scheduleRepository, never()).applyParsingResultIfCurrent(
            any(), any(), any(), any(), any(), any(), any()
        )
    }

    @ParameterizedTest
    @EnumSource(
        value = ParsingTimeStatus::class,
        names = ["WAIT"],
        mode = EnumSource.Mode.EXCLUDE,
    )
    fun `terminal parsing states ignore duplicate tasks`(status: ParsingTimeStatus) {
        val schedule = createSchedule().apply { parsingTimeStatus = status }
        val task = ScheduleTimeParsingTask(schedule)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))

        val aiAttempted = worker.run(task)

        assertThat(aiAttempted).isFalse()
        assertThat(schedule.parsingTimeStatus).isEqualTo(status)
        verify(scheduleTimeParsingService, never()).parseScheduleTime(anyOrNull())
        verify(scheduleRepository, never()).updateParsingStatusIfCurrent(any(), any(), any(), any())
        verify(scheduleRepository, never()).applyParsingResultIfCurrent(
            any(), any(), any(), any(), any(), any(), any()
        )
    }

    @Test
    fun `if time info already exists, it changes status into ALREADY_HAVE_TIME_INFO`() {
        val schedule = createSchedule(content = "변경한 제목 10시").apply {
            startDateTime = LocalDateTime.of(2023, 3, 1, 10, 0)
            endDateTime = LocalDateTime.of(2023, 3, 1, 11, 0)
            contentWithoutTime = ""
        }
        val task = ScheduleTimeParsingTask(schedule)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))

        worker.run(task)

        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.ALREADY_HAVE_TIME_INFO)
        assertThat(schedule.content()).isEqualTo("변경한 제목 10시")
        assertThat(schedule.contentWithoutTime).isEmpty()
        verify(scheduleTimeParsingService, never()).parseScheduleTime(anyOrNull())
        verify(scheduleRepository).updateParsingStatusIfCurrent(any(), any(), any(), any())
    }

    @Test
    fun `if fail to parse, it changes status into FAILED`() {
        val schedule = createSchedule()
        val task = ScheduleTimeParsingTask(schedule)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))
        val response = ScheduleTimeParsingResponse(
            result = false,
        )
        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull())).thenReturn(response)

        val aiAttempted = worker.run(task)

        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.FAILED)
        assertThat(aiAttempted).isTrue()
        verify(scheduleRepository).updateParsingStatusIfCurrent(any(), any(), any(), any())
    }

    @Test
    fun `withdrawn owner consent immediately before parsing changes status to SKIP without external request`() {
        val schedule = createSchedule(content = "3시 회의")
        val task = ScheduleTimeParsingTask(schedule)
        whenever(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))
        whenever(aiScheduleParsingConsentService.hasCurrentConsent(schedule.member.id!!)).thenReturn(false)

        val aiAttempted = worker.run(task)

        assertThat(aiAttempted).isFalse()
        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.SKIP)
        verify(scheduleRepository).updateParsingStatusIfCurrent(
            schedule.id,
            schedule.parsingGeneration,
            ParsingTimeStatus.WAIT,
            ParsingTimeStatus.SKIP,
        )
        verify(scheduleTimeParsingService, never()).parseScheduleTime(anyOrNull())
    }

    @Test
    fun `withdrawn owner consent takes priority over no time indicator pre-filter`() {
        val schedule = createSchedule(content = "점심 먹기")
        val task = ScheduleTimeParsingTask(schedule)
        whenever(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))
        whenever(aiScheduleParsingConsentService.hasCurrentConsent(schedule.member.id!!)).thenReturn(false)

        val aiAttempted = worker.run(task)

        assertThat(aiAttempted).isFalse()
        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.SKIP)
        verify(scheduleRepository).updateParsingStatusIfCurrent(
            schedule.id,
            schedule.parsingGeneration,
            ParsingTimeStatus.WAIT,
            ParsingTimeStatus.SKIP,
        )
        verify(scheduleTimeParsingService, never()).parseScheduleTime(anyOrNull())
    }

    @Test
    fun `If there is no time information, it changes status into NO_TIME_INFO`() {
        val schedule = createSchedule()
        val task = ScheduleTimeParsingTask(schedule)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))
        val response = ScheduleTimeParsingResponse(
            result = true,
            hasTime = false,
        )
        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull())).thenReturn(response)

        val aiAttempted = worker.run(task)

        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.NO_TIME_INFO)
        assertThat(aiAttempted).isTrue()
        verify(scheduleRepository).updateParsingStatusIfCurrent(any(), any(), any(), any())
    }

    @Test
    fun `When parsing is successful, it updates the schedule`() {
        val schedule = createSchedule()
        val task = ScheduleTimeParsingTask(schedule)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))

        val newStart = LocalDateTime.of(2025, 3, 3, 9, 0)
        val newEnd = LocalDateTime.of(2025, 3, 3, 10, 0)
        val response = ScheduleTimeParsingResponse(
            result = true,
            hasTime = true,
            startDateTime = newStart.toString(),
            endDateTime = newEnd.toString(),
            content = "시간정보 제거된 내용"
        )
        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull())).thenReturn(response)

        val aiAttempted = worker.run(task)

        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.PARSED)
        assertThat(schedule.startDateTime).isEqualTo(newStart)
        assertThat(schedule.endDateTime).isEqualTo(newEnd)
        assertThat(schedule.contentWithoutTime).isEqualTo("시간정보 제거된 내용")
        assertThat(aiAttempted).isTrue()

        verify(scheduleRepository).applyParsingResultIfCurrent(
            any(), any(), any(), any(), any(), any(), any()
        )
    }

    @Test
    fun `reparsing an edited all-day schedule replaces the previous AI result`() {
        val schedule = createSchedule(content = "꿈아띠 10~12시").apply {
            contentWithoutTime = ""
            parsingTimeStatus = ParsingTimeStatus.WAIT
        }
        val task = ScheduleTimeParsingTask(schedule)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))
        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull())).thenReturn(
            ScheduleTimeParsingResponse(
                result = true,
                hasTime = true,
                startDateTime = "2025-03-03T10:00:00",
                endDateTime = "2025-03-03T12:00:00",
                content = "꿈아띠",
            )
        )

        val aiAttempted = worker.run(task)

        assertThat(schedule.content).isEqualTo("꿈아띠 10~12시")
        assertThat(schedule.contentWithoutTime).isEqualTo("꿈아띠")
        assertThat(schedule.content()).isEqualTo("꿈아띠")
        assertThat(schedule.startDateTime).isEqualTo(LocalDateTime.of(2025, 3, 3, 10, 0))
        assertThat(schedule.endDateTime).isEqualTo(LocalDateTime.of(2025, 3, 3, 12, 0))
        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.PARSED)
        assertThat(aiAttempted).isTrue()
    }

    @Test
    fun `edited title without time remains visible when pre-filter finds no time`() {
        val schedule = createSchedule(content = "새 꿈아띠").apply {
            contentWithoutTime = ""
            parsingTimeStatus = ParsingTimeStatus.WAIT
        }
        val task = ScheduleTimeParsingTask(schedule)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))

        val aiAttempted = worker.run(task)

        assertThat(schedule.content()).isEqualTo("새 꿈아띠")
        assertThat(schedule.contentWithoutTime).isEmpty()
        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.NO_TIME_INFO)
        assertThat(aiAttempted).isFalse()
        verify(scheduleTimeParsingService, never()).parseScheduleTime(anyOrNull())
    }

    @Test
    fun `stale AI response does not overwrite an edit made while parsing`() {
        val scheduleId = UUID.randomUUID()
        val parsingSchedule = createSchedule(content = "꿈아띠 12~14시")
        ReflectionTestUtils.setField(parsingSchedule, "id", scheduleId)
        val task = ScheduleTimeParsingTask(parsingSchedule)
        val editedSchedule = createSchedule(content = "새 제목").apply {
            ReflectionTestUtils.setField(this, "id", scheduleId)
            startDateTime = LocalDateTime.of(2025, 3, 4, 0, 0)
            endDateTime = startDateTime
            contentWithoutTime = ""
            parsingTimeStatus = ParsingTimeStatus.WAIT
        }
        `when`(scheduleRepository.findById(scheduleId)).thenReturn(Optional.of(parsingSchedule))
        whenever(
            scheduleRepository.applyParsingResultIfCurrent(
                any(), any(), any(), any(), any(), any(), any()
            )
        ).thenReturn(0)
        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull())).thenReturn(
            ScheduleTimeParsingResponse(
                result = true,
                hasTime = true,
                startDateTime = "2025-03-03T12:00:00",
                endDateTime = "2025-03-03T14:00:00",
                content = "꿈아띠",
            )
        )

        worker.run(task)

        assertThat(editedSchedule.content()).isEqualTo("새 제목")
        assertThat(editedSchedule.startDateTime).isEqualTo(LocalDateTime.of(2025, 3, 4, 0, 0))
        assertThat(editedSchedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.WAIT)
        verify(scheduleRepository).applyParsingResultIfCurrent(
            any(), any(), any(), any(), any(), any(), any()
        )
    }

    @Test
    fun `stale parsing exception does not mark current generation failed or notify Slack`() {
        val schedule = createSchedule(content = "3시 회의")
        val task = ScheduleTimeParsingTask(schedule)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))
        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull()))
            .thenThrow(RuntimeException("old request failed"))
        whenever(
            scheduleRepository.updateParsingStatusIfCurrent(any(), any(), any(), any())
        ).thenReturn(0)

        worker.run(task)

        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.WAIT)
        verify(slackNotifier, never()).call(any<SlackMessage>())
    }

    @Test
    fun `interrupted AI call leaves schedule waiting for startup recovery`() {
        val schedule = createSchedule(content = "3시 회의")
        val task = ScheduleTimeParsingTask(schedule)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))
        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull()))
            .thenThrow(RuntimeException(InterruptedException("application shutdown")))

        try {
            val aiAttempted = worker.run(task)

            assertThat(aiAttempted).isFalse()
            assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.WAIT)
            verify(scheduleRepository, never()).updateParsingStatusIfCurrent(any(), any(), any(), any())
            verify(slackNotifier, never()).call(any<SlackMessage>())
        } finally {
            Thread.interrupted()
        }
    }

    @Test
    fun `duplicate task does not overwrite PARSED status after the first task succeeds`() {
        val schedule = createSchedule(content = "3시 회의")
        val task = ScheduleTimeParsingTask(schedule)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))
        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull())).thenReturn(
            ScheduleTimeParsingResponse(
                result = true,
                hasTime = true,
                startDateTime = "2025-03-03T15:00:00",
                endDateTime = "2025-03-03T15:00:00",
                content = "회의",
            )
        )

        worker.run(task)
        worker.run(task)

        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.PARSED)
        verify(scheduleTimeParsingService, times(1)).parseScheduleTime(anyOrNull())
        verify(scheduleRepository, times(1)).applyParsingResultIfCurrent(
            any(), any(), any(), any(), any(), any(), any()
        )
    }

    @Test
    fun `duplicate task does not parse again after NO_TIME_INFO`() {
        val schedule = createSchedule(content = "프로젝트 2026")
        val task = ScheduleTimeParsingTask(schedule)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))
        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull())).thenReturn(
            ScheduleTimeParsingResponse(result = true, hasTime = false)
        )

        worker.run(task)
        worker.run(task)

        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.NO_TIME_INFO)
        verify(scheduleTimeParsingService, times(1)).parseScheduleTime(anyOrNull())
        verify(scheduleRepository, times(1)).updateParsingStatusIfCurrent(any(), any(), any(), any())
    }

    @Test
    fun `duplicate task does not parse midnight result again`() {
        val schedule = createSchedule(content = "0시 회의")
        val task = ScheduleTimeParsingTask(schedule)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))
        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull())).thenReturn(
            ScheduleTimeParsingResponse(
                result = true,
                hasTime = true,
                startDateTime = "2025-03-03T00:00:00",
                endDateTime = "2025-03-03T00:00:00",
                content = "회의",
            )
        )

        worker.run(task)
        worker.run(task)

        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.PARSED)
        verify(scheduleTimeParsingService, times(1)).parseScheduleTime(anyOrNull())
        verify(scheduleRepository, times(1)).applyParsingResultIfCurrent(
            any(), any(), any(), any(), any(), any(), any()
        )
    }

    @Test
    fun `special midnight text reaches time parsing service`() {
        val schedule = createSchedule(content = "자정 회의")
        val task = ScheduleTimeParsingTask(schedule)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))
        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull())).thenReturn(
            ScheduleTimeParsingResponse(
                result = true,
                hasTime = true,
                startDateTime = "2025-03-03T00:00:00",
                endDateTime = "2025-03-03T00:00:00",
                content = "회의",
            )
        )

        worker.run(task)

        verify(scheduleTimeParsingService).parseScheduleTime(anyOrNull())
        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.PARSED)
    }

    @Test
    fun `parsed end before start is rejected`() {
        val schedule = createSchedule(content = "18시부터 10시 회의")
        val task = ScheduleTimeParsingTask(schedule)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))
        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull())).thenReturn(
            ScheduleTimeParsingResponse(
                result = true,
                hasTime = true,
                startDateTime = "2025-03-03T18:00:00",
                endDateTime = "2025-03-03T10:00:00",
                content = "회의",
            )
        )

        worker.run(task)

        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.FAILED)
        assertThat(schedule.startDateTime).isEqualTo(LocalDateTime.of(2025, 3, 3, 0, 0))
        assertThat(schedule.endDateTime).isEqualTo(LocalDateTime.of(2025, 3, 3, 0, 0))
    }

    @Test
    fun `parsed date outside requested date is rejected`() {
        val schedule = createSchedule(content = "10시 회의")
        val task = ScheduleTimeParsingTask(schedule)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))
        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull())).thenReturn(
            ScheduleTimeParsingResponse(
                result = true,
                hasTime = true,
                startDateTime = "2025-03-04T10:00:00",
                endDateTime = "2025-03-04T11:00:00",
                content = "회의",
            )
        )

        worker.run(task)

        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.FAILED)
        assertThat(schedule.startDateTime).isEqualTo(LocalDateTime.of(2025, 3, 3, 0, 0))
        assertThat(schedule.endDateTime).isEqualTo(LocalDateTime.of(2025, 3, 3, 0, 0))
    }

    @Test
    fun `if date is not parsable and DateTimeParseException is thrown, it changes status into FAILED`() {
        val schedule = createSchedule()
        val task = ScheduleTimeParsingTask(schedule)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))

        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull())).thenReturn(
            ScheduleTimeParsingResponse(
                result = true,
                hasTime = true,
                startDateTime = "can not parse date",
                endDateTime = "not parseable date",
            )
        )

        worker.run(task)

        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.FAILED)
        verify(scheduleRepository).updateParsingStatusIfCurrent(any(), any(), any(), any())
    }

    @Test
    fun `if content has no time-related text, status changes to NO_TIME_INFO`() {
        val schedule = createSchedule(content = "점심 먹기")
        val task = ScheduleTimeParsingTask(schedule)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))

        val aiAttempted = worker.run(task)

        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.NO_TIME_INFO)
        assertThat(aiAttempted).isFalse()
        verify(scheduleRepository).updateParsingStatusIfCurrent(any(), any(), any(), any())
        verify(scheduleTimeParsingService, never()).parseScheduleTime(anyOrNull())
    }

    @Test
    fun `if content has Arabic numbers, parsing should proceed`() {
        val schedule = createSchedule(content = "3시 회의")
        val task = ScheduleTimeParsingTask(schedule)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))

        val response = ScheduleTimeParsingResponse(
            result = true,
            hasTime = true,
            startDateTime = "2025-03-03T15:00:00",
            endDateTime = "2025-03-03T15:00:00",
            content = "회의"
        )
        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull())).thenReturn(response)

        worker.run(task)

        verify(scheduleTimeParsingService).parseScheduleTime(anyOrNull())
        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.PARSED)
    }

    @Test
    fun `if content has Korean numbers, parsing should proceed`() {
        val schedule = createSchedule(content = "세시 회의")
        val task = ScheduleTimeParsingTask(schedule)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))

        val response = ScheduleTimeParsingResponse(
            result = true,
            hasTime = true,
            startDateTime = "2025-03-03T15:00:00",
            endDateTime = "2025-03-03T15:00:00",
            content = "회의"
        )
        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull())).thenReturn(response)

        worker.run(task)

        verify(scheduleTimeParsingService).parseScheduleTime(anyOrNull())
        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.PARSED)
    }

    @Test
    fun `if content has mixed numbers and non-time text, parsing should proceed`() {
        val schedule = createSchedule(content = "5일 여행 계획")
        val task = ScheduleTimeParsingTask(schedule)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))

        val response = ScheduleTimeParsingResponse(
            result = true,
            hasTime = false
        )
        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull())).thenReturn(response)

        worker.run(task)

        verify(scheduleTimeParsingService).parseScheduleTime(anyOrNull())
        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.NO_TIME_INFO)
        assertThat(schedule.content()).isEqualTo("5일 여행 계획")
        assertThat(schedule.contentWithoutTime).isEmpty()
    }

    @Test
    fun `when exception is thrown during parsing, slack notification is sent`() {
        val schedule = createSchedule()
        val task = ScheduleTimeParsingTask(schedule)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))
        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull()))
            .thenThrow(RuntimeException("API connection failed"))

        worker.run(task)

        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.FAILED)
        verify(slackNotifier).call(any<SlackMessage>())
    }

    @Test
    fun `when parsing fails with errorMessage, slack notification is sent`() {
        val schedule = createSchedule()
        val task = ScheduleTimeParsingTask(schedule)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))
        val response = ScheduleTimeParsingResponse(
            result = false,
            errorMessage = "LLM returned invalid format"
        )
        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull())).thenReturn(response)

        worker.run(task)

        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.FAILED)
        verify(slackNotifier).call(any<SlackMessage>())
    }

    @Test
    fun `Slack parsing error notification excludes schedule content and raw AI response`() {
        val privateContent = "비공개 진료 일정 3시"
        val rawAiResponse = "raw-provider-response-with-private-data"
        val schedule = createSchedule(content = privateContent)
        val task = ScheduleTimeParsingTask(schedule)
        whenever(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))
        whenever(scheduleTimeParsingService.parseScheduleTime(anyOrNull())).thenReturn(
            ScheduleTimeParsingResponse(
                result = false,
                errorMessage = "invalid response format",
                rawResponse = rawAiResponse,
            )
        )
        val messageCaptor = argumentCaptor<SlackMessage>()

        worker.run(task)

        verify(slackNotifier).call(messageCaptor.capture())
        val fields = readAttachments(messageCaptor.firstValue).flatMap(::readFields)
        assertThat(fields.mapNotNull(::readFieldTitle))
            .containsExactly("Failure Kind")
            .doesNotContain("Content", "LLM Response", "Error Message")
        assertThat(fields.mapNotNull(::readFieldValue))
            .containsExactly("INVALID_RESPONSE")
            .doesNotContain(schedule.id.toString(), privateContent, rawAiResponse)
    }

    @Test
    fun `when parsing fails without error info, slack notification is not sent`() {
        val schedule = createSchedule()
        val task = ScheduleTimeParsingTask(schedule)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))
        val response = ScheduleTimeParsingResponse(
            result = false,
            errorMessage = null,
            rawResponse = null
        )
        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull())).thenReturn(response)

        worker.run(task)

        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.FAILED)
        verify(slackNotifier, never()).call(any<SlackMessage>())
    }

    @Suppress("UNCHECKED_CAST")
    private fun readAttachments(message: SlackMessage): List<SlackAttachment> {
        val field = SlackMessage::class.java.getDeclaredField("attach")
        field.isAccessible = true
        return field.get(message) as? List<SlackAttachment> ?: emptyList()
    }

    @Suppress("UNCHECKED_CAST")
    private fun readFields(attachment: SlackAttachment): List<SlackField> {
        val field = SlackAttachment::class.java.getDeclaredField("fields")
        field.isAccessible = true
        return field.get(attachment) as? List<SlackField> ?: emptyList()
    }

    private fun readFieldTitle(field: SlackField): String? {
        val titleField = SlackField::class.java.getDeclaredField("title")
        titleField.isAccessible = true
        return titleField.get(field) as? String
    }

    private fun readFieldValue(field: SlackField): String? {
        val valueField = SlackField::class.java.getDeclaredField("value")
        valueField.isAccessible = true
        return valueField.get(field) as? String
    }

}
