package com.tistory.shanepark.dutypark.team.controller

import ch.qos.logback.classic.Logger as LogbackLogger
import ch.qos.logback.core.read.ListAppender
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchResult
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTeamResult
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTemplate
import com.tistory.shanepark.dutypark.duty.batch.service.DutyBatchSungsimService
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
import com.tistory.shanepark.dutypark.team.service.TeamService
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.slf4j.LoggerFactory
import org.springframework.context.ApplicationContext
import org.springframework.mock.web.MockMultipartFile
import org.springframework.test.util.ReflectionTestUtils
import org.mockito.kotlin.any
import org.mockito.kotlin.eq
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import java.time.LocalDate
import java.time.YearMonth
import java.util.Optional

class TeamManageControllerAuditTest {
    private val teamService: TeamService = mock()
    private val memberService: MemberService = mock()
    private val teamRepository: TeamRepository = mock()
    private val applicationContext: ApplicationContext = mock()
    private val batchService: DutyBatchSungsimService = mock()
    private val controller = TeamManageController(teamService, memberService, teamRepository, applicationContext)

    @Test
    fun `partial team batch result logs failed member names and error codes`() {
        val team = Team("Test Team").also {
            ReflectionTestUtils.setField(it, "id", 44L)
            it.dutyBatchTemplate = DutyBatchTemplate.SUNGSIM_CAKE
        }
        whenever(teamRepository.findById(team.id!!)).thenReturn(Optional.of(team))
        whenever(applicationContext.getBean(DutyBatchSungsimService::class.java)).thenReturn(batchService)
        whenever(batchService.batchUploadTeam(any(), eq(team.id!!), eq(YearMonth.of(2024, 1)))).thenReturn(
            DutyBatchTeamResult.success(
                startDate = LocalDate.of(2024, 1, 1),
                endDate = LocalDate.of(2024, 1, 31),
                dutyBatchResult = listOf(
                    "Imported Member" to DutyBatchResult.success(
                        22,
                        9,
                        LocalDate.of(2024, 1, 1),
                        LocalDate.of(2024, 1, 31),
                    ),
                    "Missing Member" to DutyBatchResult.fail("dutyBatch.nameNotFound"),
                ),
            )
        )

        val logger = LoggerFactory.getLogger(TeamManageController::class.java) as LogbackLogger
        val appender = ListAppender<ch.qos.logback.classic.spi.ILoggingEvent>().apply {
            context = logger.loggerContext
            start()
        }
        logger.addAppender(appender)
        try {
            val result = controller.uploadBatchTemplate(
                loginMember = LoginMember(id = 5L, name = "Admin"),
                teamId = team.id!!,
                file = MockMultipartFile("file", "duty.xlsx", "application/octet-stream", byteArrayOf(1)),
                year = 2024,
                month = 1,
            )

            assertThat(result.result).isTrue()
        } finally {
            logger.detachAppender(appender)
            appender.stop()
        }

        assertThat(appender.list).hasSize(1)
        assertThat(appender.list.single().formattedMessage)
            .contains(
                "duty_batch.team_uploaded",
                "Test Team",
                "Admin",
                "\"successfulMembers\":1",
                "\"failedMembers\":1",
                "Missing Member",
                "dutyBatch.nameNotFound",
            )
    }
}
