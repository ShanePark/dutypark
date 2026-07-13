package com.tistory.shanepark.dutypark.team.controller

import com.tistory.shanepark.dutypark.schedule.domain.dto.TeamScheduleDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.domain.dto.TeamScheduleSaveDto
import com.tistory.shanepark.dutypark.team.service.TeamScheduleService
import com.tistory.shanepark.dutypark.team.service.TeamService
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.never
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import java.time.LocalDateTime
import java.util.UUID

@ExtendWith(MockitoExtension::class)
class TeamScheduleControllerTest {

    @Mock
    lateinit var teamScheduleService: TeamScheduleService

    @Mock
    lateinit var teamService: TeamService

    @InjectMocks
    lateinit var controller: TeamScheduleController

    @Test
    fun `update delegates authorization and mutation to service`() {
        val login = LoginMember(id = 1L, name = "manager")
        val scheduleId = UUID.randomUUID()
        val requestedTeamId = 10L
        val dateTime = LocalDateTime.of(2026, 7, 13, 12, 0)
        val saveDto = TeamScheduleSaveDto(
            id = scheduleId,
            teamId = requestedTeamId,
            content = "Unauthorized update",
            startDateTime = dateTime,
            endDateTime = dateTime,
        )
        val existingSchedule = TeamScheduleDto(
            id = scheduleId,
            teamId = requestedTeamId,
            content = saveDto.content,
            description = "",
            position = 0,
            year = dateTime.year,
            month = dateTime.monthValue,
            dayOfMonth = dateTime.dayOfMonth,
            startDateTime = dateTime,
            endDateTime = dateTime,
            createMember = "author",
            updateMember = "author",
        )

        whenever(teamScheduleService.update(login = login, saveDto = saveDto)).thenReturn(existingSchedule)

        val result = controller.saveSchedule(login = login, saveDto = saveDto)

        assertThat(result).isEqualTo(existingSchedule)
        verify(teamScheduleService).update(login = login, saveDto = saveDto)
        verify(teamScheduleService, never()).findById(scheduleId)
        verify(teamService, never()).checkCanManage(login = login, teamId = requestedTeamId)
    }
}
