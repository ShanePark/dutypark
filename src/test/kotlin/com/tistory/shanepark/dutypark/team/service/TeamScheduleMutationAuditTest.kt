package com.tistory.shanepark.dutypark.team.service

import ch.qos.logback.classic.Logger
import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.core.read.ListAppender
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.team.domain.dto.TeamScheduleSaveDto
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import com.tistory.shanepark.dutypark.team.domain.entity.TeamSchedule
import com.tistory.shanepark.dutypark.team.repository.TeamScheduleRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import org.slf4j.LoggerFactory
import org.springframework.test.util.ReflectionTestUtils
import java.time.LocalDateTime
import java.util.Optional

class TeamScheduleMutationAuditTest {
    @Test
    fun `team schedule update records safe times and keeps free text private`() {
        val repository = mock<TeamScheduleRepository>()
        val members = mock<MemberRepository>()
        val team = Team("Team")
        ReflectionTestUtils.setField(team, "id", 41L)
        val owner = Member("Owner")
        ReflectionTestUtils.setField(owner, "id", 11L)
        val time = LocalDateTime.of(2026, 10, 1, 0, 0)
        val schedule = TeamSchedule(team, owner, content = "private original", startDateTime = time, endDateTime = time, position = 0)
        whenever(repository.findById(schedule.id)).thenReturn(Optional.of(schedule))
        whenever(members.findById(11L)).thenReturn(Optional.of(owner))
        val service = TeamScheduleService(repository, mock(), members, mock())
        val request = TeamScheduleSaveDto(id = schedule.id, teamId = 41L, content = "private replacement", startDateTime = time.plusHours(1), endDateTime = time.plusHours(2))
        val logger = LoggerFactory.getLogger(TeamScheduleService::class.java) as Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try {
            service.update(LoginMember(id = 11L, name = "Owner"), request)
            service.update(LoginMember(id = 11L, name = "Owner"), request)
            assertThat(appender.list).hasSize(1)
            assertThat(appender.list.single().formattedMessage)
                .contains("team_schedule.updated", "startDateTimeBefore", "startDateTimeAfter", "41", "11")
                .doesNotContain("private original", "private replacement")
        } finally {
            logger.detachAppender(appender)
            appender.stop()
        }
    }
}
