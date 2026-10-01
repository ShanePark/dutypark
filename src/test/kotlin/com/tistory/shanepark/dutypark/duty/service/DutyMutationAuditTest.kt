package com.tistory.shanepark.dutypark.duty.service

import ch.qos.logback.classic.Logger
import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.core.read.ListAppender
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import org.slf4j.LoggerFactory
import org.springframework.test.util.ReflectionTestUtils
import java.time.LocalDate
import java.util.Optional

class DutyMutationAuditTest {
    @Test
    fun `manual override transition is logged and repeated assignment is silent`() {
        val repository = mock<DutyRepository>()
        val members = mock<MemberRepository>()
        val member = Member("Owner")
        ReflectionTestUtils.setField(member, "id", 11L)
        val date = LocalDate.of(2026, 10, 1)
        val duty = Duty(date, null, member, manualOverride = false)
        whenever(members.findMemberWithTeamForUpdate(11L)).thenReturn(Optional.of(member))
        whenever(repository.findByMemberAndDutyDate(member, date)).thenReturn(duty)
        val service = DutyService(repository, mock(), members, mock(), mock(), mock(), mock())
        val logger = LoggerFactory.getLogger(DutyService::class.java) as Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try {
            val request = DutyUpdateDto(2026, 10, 1, null, 11L)
            service.update(request)
            service.update(request)
            assertThat(appender.list).hasSize(1)
            assertThat(appender.list.single().formattedMessage)
                .contains("duty.updated", "manualOverride", "before", "after", "11")
        } finally {
            logger.detachAppender(appender)
            appender.stop()
        }
    }
    @Test
    fun `override reset logs only when a duty was deleted`() {
        val repository = mock<DutyRepository>()
        val members = mock<MemberRepository>()
        val member = Member("Owner")
        ReflectionTestUtils.setField(member, "id", 11L)
        val date = LocalDate.of(2026, 10, 1)
        whenever(members.findMemberWithTeamForUpdate(11L)).thenReturn(Optional.of(member))
        whenever(repository.deleteByMemberAndDutyDate(member, date)).thenReturn(1L, 0L)
        val service = DutyService(repository, mock(), members, mock(), mock(), mock(), mock())
        val logger = LoggerFactory.getLogger(DutyService::class.java) as Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try {
            service.resetOverride(11L, date)
            service.resetOverride(11L, date)
            assertThat(appender.list).hasSize(1)
            assertThat(appender.list.single().formattedMessage)
                .contains("duty.override_reset", "deletedCount", "11", "2026-10-01")
        } finally {
            logger.detachAppender(appender)
            appender.stop()
        }
    }

}
