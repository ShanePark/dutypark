package com.tistory.shanepark.dutypark.schedule.service

import ch.qos.logback.classic.Logger
import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.core.read.ListAppender
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleSaveDto
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import org.slf4j.LoggerFactory
import org.springframework.test.util.ReflectionTestUtils
import java.time.LocalDateTime
import java.util.Optional

class ScheduleMutationAuditTest {
    @Test
    fun `schedule update records changed field names without private text and suppresses repeated update`() {
        val repository = mock<ScheduleRepository>()
        val owner = Member("Owner")
        ReflectionTestUtils.setField(owner, "id", 11L)
        val time = LocalDateTime.of(2026, 10, 1, 0, 0)
        val schedule = Schedule(owner, "private original", startDateTime = time, endDateTime = time)
        whenever(repository.findById(schedule.id)).thenReturn(Optional.of(schedule))
        val service = ScheduleService(repository, mock(), mock(), mock(), mock(), mock(), mock(), mock(), mock(), mock(), mock())
        val request = ScheduleSaveDto(id = schedule.id, memberId = 11L, content = "private replacement", description = "private description", startDateTime = time, endDateTime = time)
        val logger = LoggerFactory.getLogger(ScheduleService::class.java) as Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try {
            service.updateSchedule(LoginMember(id = 11L, name = "Owner"), request)
            service.updateSchedule(LoginMember(id = 11L, name = "Owner"), request)
            assertThat(appender.list).hasSize(1)
            assertThat(appender.list.single().formattedMessage)
                .contains("schedule.updated", "content", "description", "11")
                .doesNotContain("private original", "private replacement", "private description")
        } finally {
            logger.detachAppender(appender)
            appender.stop()
        }
    }
}
