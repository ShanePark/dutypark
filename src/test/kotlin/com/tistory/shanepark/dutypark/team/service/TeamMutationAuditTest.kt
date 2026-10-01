package com.tistory.shanepark.dutypark.team.service

import ch.qos.logback.classic.Logger
import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.core.read.ListAppender
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTemplate
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import org.slf4j.LoggerFactory
import org.springframework.test.util.ReflectionTestUtils
import java.util.Optional

class TeamMutationAuditTest {
    @Test
    fun `template changes are logged once with before and after`() {
        val repository = mock<TeamRepository>()
        val team = Team("Team")
        ReflectionTestUtils.setField(team, "id", 41L)
        whenever(repository.findById(41L)).thenReturn(Optional.of(team))
        val service = TeamService(repository, mock(), mock(), mock(), mock(), mock(), mock())
        val logger = LoggerFactory.getLogger(TeamService::class.java) as Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try {
            service.updateBatchTemplate(41L, DutyBatchTemplate.SUNGSIM_CAKE)
            service.updateBatchTemplate(41L, DutyBatchTemplate.SUNGSIM_CAKE)
            assertThat(appender.list).hasSize(1)
            assertThat(appender.list.single().formattedMessage)
                .contains("team.batch_template_updated", "41", "SUNGSIM_CAKE", "before", "after")
        } finally {
            logger.detachAppender(appender)
            appender.stop()
        }
    }
}
