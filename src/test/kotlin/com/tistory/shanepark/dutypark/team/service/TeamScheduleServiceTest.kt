package com.tistory.shanepark.dutypark.team.service

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.common.exceptions.InvalidScheduleTimeRangeExeption
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.domain.dto.TeamScheduleSaveDto
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import com.tistory.shanepark.dutypark.team.domain.entity.TeamSchedule
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
import com.tistory.shanepark.dutypark.team.repository.TeamScheduleRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.any
import org.mockito.kotlin.eq
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.springframework.test.util.ReflectionTestUtils
import java.time.LocalDate
import java.time.LocalDateTime
import java.util.*

@ExtendWith(MockitoExtension::class)
class TeamScheduleServiceTest {

    @Mock
    lateinit var teamScheduleRepository: TeamScheduleRepository

    @Mock
    lateinit var teamRepository: TeamRepository

    @Mock
    lateinit var memberRepository: MemberRepository

    @InjectMocks
    lateinit var teamScheduleService: TeamScheduleService

    @Test
    fun `create should save schedule and return TeamScheduleDto`() {
        // Given
        val loginMember = LoginMember(id = 1L, name = "Test Author")
        val author = Member("Test Author")
        val team = makeTeam()

        val dateTime = LocalDateTime.of(2025, 3, 21, 0, 0)
        val saveDto = TeamScheduleSaveDto(
            teamId = 10L,
            content = "Meeting",
            description = "Project discussion",
            startDateTime = dateTime,
            endDateTime = dateTime
        )
        val savedSchedule = savedSchedule(team, author, saveDto)

        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(author))
        whenever(teamRepository.findById(10L)).thenReturn(Optional.of(team))
        whenever(teamScheduleRepository.findTeamSchedulesOfTeamRangeIn(any<Team>(), any(), any())).thenReturn(listOf())
        whenever(teamScheduleRepository.save(any())).thenReturn(savedSchedule)

        // When
        val result = teamScheduleService.create(loginMember, saveDto)

        // Then
        assertThat(result.content).isEqualTo(saveDto.content)
        assertThat(result.createMember).isEqualTo(author.name)
        assertThat(result.position).isEqualTo(0)
        verify(teamScheduleRepository).save(any())
    }

    private fun savedSchedule(
        team: Team,
        author: Member,
        saveDto: TeamScheduleSaveDto
    ): TeamSchedule {
        val savedSchedule = TeamSchedule(
            team = team,
            createMember = author,
            updateMember = author,
            content = saveDto.content,
            description = saveDto.description,
            startDateTime = saveDto.startDateTime,
            endDateTime = saveDto.endDateTime,
            position = 0
        )
        return savedSchedule
    }

    @Test
    fun `create should assign position based on existing schedules`() {
        // Given
        val loginMember = LoginMember(id = 1L, name = "Author")
        val author = Member("Author")
        val team = makeTeam("Team B")

        val dateTime = LocalDateTime.of(2025, 3, 22, 10, 0)
        val saveDto = TeamScheduleSaveDto(
            teamId = 20L,
            content = "Another Meeting",
            description = "Important",
            startDateTime = dateTime,
            endDateTime = dateTime.plusHours(1)
        )

        val existingSchedules = listOf(
            createSchedule(), createSchedule(), createSchedule()
        )

        val savedSchedule = savedSchedule(team, author, saveDto)

        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(author))
        whenever(teamRepository.findById(20L)).thenReturn(Optional.of(team))
        whenever(teamScheduleRepository.findTeamSchedulesOfTeamRangeIn(any(), any(), any()))
            .thenReturn(existingSchedules)
        whenever(teamScheduleRepository.save(any())).thenReturn(savedSchedule)

        // When
        val result = teamScheduleService.create(loginMember, saveDto)

        // Then
        assertThat(result.position).isEqualTo(3)
    }

    @Test
    fun `create should throw exception when startDateTime is after endDateTime`() {
        val now = LocalDateTime.now()
        assertThrows<InvalidScheduleTimeRangeExeption> {
            TeamScheduleSaveDto(
                teamId = 1L,
                content = "Invalid Time",
                startDateTime = now.plusHours(1),
                endDateTime = now
            )
        }
    }

    @Test
    fun `update should update schedule with new values and updateMember`() {
        // Given
        val loginMember = LoginMember(id = 1L, name = "Editor")
        val author = Member("Editor")

        val originalMember = Member("Original")
        val team = makeTeam()

        val oldSchedule = TeamSchedule(
            team = team,
            createMember = originalMember,
            content = "Old",
            description = "Old Desc",
            startDateTime = LocalDateTime.of(2025, 3, 20, 10, 0),
            endDateTime = LocalDateTime.of(2025, 3, 20, 11, 0),
            position = 0
        )

        val updatedStart = LocalDateTime.of(2025, 3, 21, 15, 0)
        val updatedEnd = updatedStart.plusHours(2)

        val saveDto = TeamScheduleSaveDto(
            id = oldSchedule.id,
            teamId = team.id ?: 1L,
            content = "Updated Content",
            description = "Updated Description",
            startDateTime = updatedStart,
            endDateTime = updatedEnd
        )

        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(author))
        whenever(teamScheduleRepository.findById(oldSchedule.id)).thenReturn(Optional.of(oldSchedule))

        // When
        teamScheduleService.update(loginMember, saveDto)

        // Then
        assertThat(oldSchedule.content).isEqualTo("Updated Content")
        assertThat(oldSchedule.description).isEqualTo("Updated Description")
        assertThat(oldSchedule.startDateTime).isEqualTo(updatedStart)
        assertThat(oldSchedule.endDateTime).isEqualTo(updatedEnd)
        assertThat(oldSchedule.updateMember).isEqualTo(author)
    }

    private fun makeTeam(name: String = "Team A"): Team {
        val team = Team(name)
        ReflectionTestUtils.setField(team, "id", 1L)
        return team
    }

    @Test
    fun `update should throw when schedule not found`() {
        val saveDto = TeamScheduleSaveDto(
            id = UUID.randomUUID(),
            teamId = 1L,
            content = "X",
            startDateTime = LocalDateTime.now(),
            endDateTime = LocalDateTime.now()
        )
        val loginMember = LoginMember(id = 1L, name = "Editor")

        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(Member("Editor")))
        whenever(teamScheduleRepository.findById(saveDto.id!!)).thenReturn(Optional.empty())

        assertThrows<NoSuchElementException> {
            teamScheduleService.update(loginMember, saveDto)
        }
    }

    @Test
    fun `delete should remove schedule by id`() {
        // given
        val scheduleId = UUID.randomUUID()
        val schedule = createSchedule()

        whenever(teamScheduleRepository.findById(scheduleId)).thenReturn(Optional.of(schedule))

        // when
        teamScheduleService.delete(scheduleId)

        // then
        verify(teamScheduleRepository).delete(schedule)
    }

    @Test
    fun `findTeamSchedules should return schedules within calendar range`() {
        // Given
        val team = makeTeam("Team C")
        val teamId = 1L
        ReflectionTestUtils.setField(team, "id", teamId)
        val calendarView = CalendarView(2025, 3)

        val rangeFromDateTime = LocalDate.of(2025, 2, 23).atStartOfDay()
        val inRangeStart = rangeFromDateTime.plusHours(1)
        val rangeUntilDateTime = LocalDate.of(2025, 4, 5).atStartOfDay()
        val outOfRangeBefore = rangeFromDateTime.minusDays(1)
        val outOfRangeAfter = rangeUntilDateTime.plusDays(1)

        val inRange1 = createSchedule(start = inRangeStart, end = inRangeStart)
        val inRange2 = createSchedule(start = rangeUntilDateTime, end = rangeUntilDateTime)
        val rangeBefore = createSchedule(start = outOfRangeBefore, end = outOfRangeBefore)
        val rangeAfter = createSchedule(start = outOfRangeAfter, end = outOfRangeAfter)
        val schedules = listOf(inRange1, inRange2, rangeBefore, rangeAfter)

        whenever(teamRepository.findById(teamId)).thenReturn(Optional.of(team))
        whenever(
            teamScheduleRepository.findTeamSchedulesOfTeamRangeIn(
                eq(team),
                eq(calendarView.rangeFromDateTime),
                eq(calendarView.rangeUntilDateTime)
            )
        ).thenReturn(schedules)

        // When
        val result = teamScheduleService.findTeamSchedules(teamId, calendarView)

        // Then
        val ids = result.flatMap { l -> l }
            .map { s -> s.id }
            .distinct()
            .toSet()
        assertThat(ids).contains(inRange1.id)
        assertThat(ids).contains(inRange2.id)
        assertThat(ids).doesNotContain(rangeBefore.id)
        assertThat(ids).doesNotContain(rangeAfter.id)
        assertThat(result[0]).hasSize(1)
        assertThat(result[0].first().id).isEqualTo(inRange1.id)
        assertThat(result[41]).hasSize(1)
        assertThat(result[41].first().id).isEqualTo(inRange2.id)
    }

    @Test
    fun `multi-day schedules should spread correctly across the calendar view`() {
        // Given
        val team = makeTeam("Team Multi")
        val teamId = 2L
        ReflectionTestUtils.setField(team, "id", teamId)
        val calendarView = CalendarView(2025, 3)

        val spanningSchedule = createSchedule(
            start = LocalDate.of(2025, 2, 28).atStartOfDay(),
            end = LocalDate.of(2025, 3, 3).atStartOfDay()
        )

        val fullMonthSchedule =
            createSchedule(
                start = LocalDate.of(2025, 3, 1).atStartOfDay(),
                end = LocalDate.of(2025, 3, 31).atStartOfDay()
            )

        val schedules = listOf(spanningSchedule, fullMonthSchedule)

        whenever(teamRepository.findById(teamId)).thenReturn(Optional.of(team))
        whenever(
            teamScheduleRepository.findTeamSchedulesOfTeamRangeIn(
                eq(team),
                eq(calendarView.rangeFromDateTime),
                eq(calendarView.rangeUntilDateTime)
            )
        ).thenReturn(schedules)

        // When
        val result = teamScheduleService.findTeamSchedules(teamId, calendarView)

        // Then
        val flattened = result.flatMap { it }
        val spanningIds = flattened.filter { it.id == spanningSchedule.id }
        assertThat(spanningIds).hasSize(4) // 2/28, 3/1, 3/2, 3/3

        val fullMonthIds = flattened.filter { it.id == fullMonthSchedule.id }
        assertThat(fullMonthIds).hasSize(31) // whole March

        val feb28Index = calendarView.getIndex(LocalDate.of(2025, 2, 28))
        val mar1Index = calendarView.getIndex(LocalDate.of(2025, 3, 1))

        assertThat(result[feb28Index].map { it.id }).contains(spanningSchedule.id)
        assertThat(result[mar1Index].map { it.id }).contains(spanningSchedule.id)
        assertThat(result[mar1Index].map { it.id }).contains(fullMonthSchedule.id)
    }

    @Test
    fun `schedules from previous month overlapping with calendar view padding should appear correctly`() {
        // Given
        val team = makeTeam("Team Padding")
        val teamId = 3L
        ReflectionTestUtils.setField(team, "id", teamId)
        val calendarView = CalendarView(2025, 3)

        val schedule = createSchedule(
            start = LocalDate.of(2025, 2, 20).atStartOfDay(),
            end = LocalDate.of(2025, 2, 25).atStartOfDay()
        )

        whenever(teamRepository.findById(teamId)).thenReturn(Optional.of(team))
        whenever(
            teamScheduleRepository.findTeamSchedulesOfTeamRangeIn(
                eq(team),
                eq(calendarView.rangeFromDateTime),
                eq(calendarView.rangeUntilDateTime)
            )
        ).thenReturn(listOf(schedule))

        // When
        val result = teamScheduleService.findTeamSchedules(teamId, calendarView)

        // Then
        val date = LocalDate.of(2025, 2, 23)
        val index = calendarView.getIndex(date)
        assertThat(result[index]).hasSize(1)
        // Event : 2025-02-20 ~ 2025-02-25. 2025-02-23 is 4 days from start.
        val first = result[index][0]
        assertThat(first.id).isEqualTo(schedule.id)
        assertThat(first.startDateTime).isEqualTo(schedule.startDateTime)
        assertThat(first.endDateTime).isEqualTo(schedule.endDateTime)
        assertThat(first.daysFromStart).isEqualTo(4)

        assertThat(result[calendarView.getIndex(LocalDate.of(2025, 2, 24))]).hasSize(1)
        assertThat(result[calendarView.getIndex(LocalDate.of(2025, 2, 25))]).hasSize(1)
        assertThat(result[calendarView.getIndex(LocalDate.of(2025, 2, 26))]).isEmpty()
    }

    private fun createSchedule(
        start: LocalDateTime = LocalDateTime.now(),
        end: LocalDateTime = LocalDateTime.now()
    ): TeamSchedule {
        return TeamSchedule(
            team = makeTeam("Test Team"),
            createMember = Member("Tester"),
            content = "test",
            startDateTime = start,
            endDateTime = end,
            position = 0
        )
    }

}
