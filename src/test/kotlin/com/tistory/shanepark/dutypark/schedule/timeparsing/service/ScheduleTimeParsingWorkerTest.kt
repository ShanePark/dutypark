import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.domain.enums.ParsingTimeStatus
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.schedule.timeparsing.domain.ScheduleTimeParsingResponse
import com.tistory.shanepark.dutypark.schedule.timeparsing.domain.ScheduleTimeParsingTask
import com.tistory.shanepark.dutypark.schedule.timeparsing.service.ScheduleTimeParsingService
import com.tistory.shanepark.dutypark.schedule.timeparsing.service.ScheduleTimeParsingWorker
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.ArgumentMatchers.any
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.Mockito.*
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.anyOrNull
import java.time.LocalDateTime
import java.util.*

@ExtendWith(MockitoExtension::class)
class ScheduleTimeParsingWorkerTest {

    @Mock
    lateinit var scheduleTimeParsingService: ScheduleTimeParsingService

    @Mock
    lateinit var scheduleRepository: ScheduleRepository

    @InjectMocks
    lateinit var worker: ScheduleTimeParsingWorker

    private fun createSchedule(content: String = "3시 회의"): Schedule {
        val randomDay = LocalDateTime.of(2025, 3, 3, 0, 0, 0, 0)
        val member = Member("")
        val schedule = Schedule(member = member, content = content, startDateTime = randomDay, endDateTime = randomDay)
        return schedule
    }

    @Test
    fun `if schedule is already deleted, never run`() {
        // Given
        val scheduleId = UUID.randomUUID()
        val task = ScheduleTimeParsingTask(scheduleId = scheduleId)
        `when`(scheduleRepository.findById(scheduleId)).thenReturn(Optional.empty())

        // When
        worker.run(task)

        // Then
        verify(scheduleRepository, never()).save(any())
    }

    @Test
    fun `if the task is expired, skip`() {
        // Given
        val schedule = createSchedule()
        schedule.lastModifiedDate = LocalDateTime.now().plusHours(1)
        val task = ScheduleTimeParsingTask(scheduleId = schedule.id)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))

        // When
        worker.run(task)

        // Then
        verify(scheduleRepository, never()).save(any())
    }

    @Test
    fun `if time info already exists, it changes status into ALREADY_HAVE_TIME_INFO`() {
        // Given
        val schedule = createSchedule().apply {
            startDateTime = LocalDateTime.of(2023, 3, 1, 10, 0)
            endDateTime = LocalDateTime.of(2023, 3, 1, 11, 0)
        }
        val task = ScheduleTimeParsingTask(scheduleId = schedule.id)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))

        // When
        worker.run(task)

        // Then
        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.ALREADY_HAVE_TIME_INFO)
        verify(scheduleRepository).save(schedule)
    }

    @Test
    fun `if fail to parse, it changes status into FAILED`() {
        // Given
        val schedule = createSchedule()
        val task = ScheduleTimeParsingTask(scheduleId = schedule.id)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))
        val response = ScheduleTimeParsingResponse(
            result = false,
        )
        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull())).thenReturn(response)

        // When
        worker.run(task)

        // Then
        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.FAILED)
        verify(scheduleRepository).save(schedule)
    }

    @Test
    fun `If there is no time information, it changes status into NO_TIME_INFO`() {
        // Given
        val schedule = createSchedule()
        val task = ScheduleTimeParsingTask(scheduleId = schedule.id)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))
        val response = ScheduleTimeParsingResponse(
            result = true,
            hasTime = false,
        )
        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull())).thenReturn(response)

        // When
        worker.run(task)

        // Then
        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.NO_TIME_INFO)
        verify(scheduleRepository).save(schedule)
    }

    @Test
    fun `When parsing is successful, it updates the schedule`() {
        // Given
        val schedule = createSchedule()
        val task = ScheduleTimeParsingTask(scheduleId = schedule.id)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))

        val newStart = LocalDateTime.of(2023, 3, 1, 9, 0).toString()
        val newEnd = LocalDateTime.of(2023, 3, 1, 10, 0).toString()
        val response = ScheduleTimeParsingResponse(
            result = true,
            hasTime = true,
            startDateTime = newStart,
            endDateTime = newEnd,
            content = "시간정보 제거된 내용"
        )
        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull())).thenReturn(response)

        // When
        worker.run(task)

        // Then
        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.PARSED)
        assertThat(schedule.startDateTime).isEqualTo(newStart)
        assertThat(schedule.endDateTime).isEqualTo(newEnd)
        assertThat(schedule.contentWithoutTime).isEqualTo("시간정보 제거된 내용")

        verify(scheduleRepository).save(schedule)
    }

    @Test
    fun `if date is not parsable and DateTimeParseException is thrown, it changes status into FAILED`() {
        // Given
        val schedule = createSchedule()
        val task = ScheduleTimeParsingTask(scheduleId = schedule.id)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))

        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull())).thenReturn(
            ScheduleTimeParsingResponse(
                result = true,
                hasTime = true,
                startDateTime = "can not parse date",
                endDateTime = "not parseable date",
            )
        )

        // When
        worker.run(task)

        // Then
        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.FAILED)
        verify(scheduleRepository).save(schedule)
    }

    @Test
    fun `if content has no time-related text, status changes to NO_TIME_INFO`() {
        // Given
        val schedule = createSchedule(content = "점심 먹기")
        val task = ScheduleTimeParsingTask(scheduleId = schedule.id)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))

        // When
        worker.run(task)

        // Then
        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.NO_TIME_INFO)
        verify(scheduleRepository).save(schedule)
        verify(scheduleTimeParsingService, never()).parseScheduleTime(anyOrNull())
    }

    @Test
    fun `if content has Arabic numbers, parsing should proceed`() {
        // Given
        val schedule = createSchedule(content = "3시 회의")
        val task = ScheduleTimeParsingTask(scheduleId = schedule.id)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))

        val response = ScheduleTimeParsingResponse(
            result = true,
            hasTime = true,
            startDateTime = "2023-03-01T15:00:00",
            endDateTime = "2023-03-01T15:00:00",
            content = "회의"
        )
        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull())).thenReturn(response)

        // When
        worker.run(task)

        // Then
        verify(scheduleTimeParsingService).parseScheduleTime(anyOrNull())
        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.PARSED)
    }

    @Test
    fun `if content has Korean numbers, parsing should proceed`() {
        // Given
        val schedule = createSchedule(content = "세시 회의")
        val task = ScheduleTimeParsingTask(scheduleId = schedule.id)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))

        val response = ScheduleTimeParsingResponse(
            result = true,
            hasTime = true,
            startDateTime = "2023-03-01T15:00:00",
            endDateTime = "2023-03-01T15:00:00",
            content = "회의"
        )
        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull())).thenReturn(response)

        // When
        worker.run(task)

        // Then
        verify(scheduleTimeParsingService).parseScheduleTime(anyOrNull())
        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.PARSED)
    }

    @Test
    fun `if content has mixed numbers and non-time text, parsing should proceed`() {
        // Given
        val schedule = createSchedule(content = "5일 여행 계획")
        val task = ScheduleTimeParsingTask(scheduleId = schedule.id)
        `when`(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))

        val response = ScheduleTimeParsingResponse(
            result = true,
            hasTime = false
        )
        `when`(scheduleTimeParsingService.parseScheduleTime(anyOrNull())).thenReturn(response)

        // When
        worker.run(task)

        // Then
        verify(scheduleTimeParsingService).parseScheduleTime(anyOrNull())
        assertThat(schedule.parsingTimeStatus).isEqualTo(ParsingTimeStatus.NO_TIME_INFO)
    }

}
