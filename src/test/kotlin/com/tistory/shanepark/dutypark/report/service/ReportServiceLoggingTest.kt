package com.tistory.shanepark.dutypark.report.service

import ch.qos.logback.classic.Logger
import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.core.read.ListAppender
import com.tistory.shanepark.dutypark.common.logging.toAuditActor
import com.tistory.shanepark.dutypark.member.block.service.BlockService
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.report.domain.dto.CreateReportRequest
import com.tistory.shanepark.dutypark.report.domain.entity.ContentReport
import com.tistory.shanepark.dutypark.report.domain.enums.ReportReason
import com.tistory.shanepark.dutypark.report.domain.enums.ReportStatus
import com.tistory.shanepark.dutypark.report.domain.enums.ReportTargetType
import com.tistory.shanepark.dutypark.report.repository.ContentReportRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import java.util.Optional
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.kotlin.any
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.verifyNoMoreInteractions
import org.mockito.kotlin.whenever
import org.slf4j.LoggerFactory
import org.springframework.test.util.ReflectionTestUtils

class ReportServiceLoggingTest {
    private val repository: ContentReportRepository = mock()
    private val members: MemberRepository = mock()
    private val blockService: BlockService = mock()
    private val service = ReportService(repository, members, mock(), mock(), mock(), blockService, mock())

    @Test
    fun `duplicate report also block preserves impersonator and uses reporter fallback for internal caller`() {
        val reporter = member(1L, "Reporter")
        val owner = member(2L, "Owner")
        val actor = LoginMember(id = 1L, name = "Reporter", isImpersonating = true, originalMemberId = 99L)
        val request = CreateReportRequest(ReportTargetType.MEMBER, "2", ReportReason.SPAM, alsoBlock = true)
        val report = ContentReport(reporter, owner, request.targetType, request.targetId, request.reason,
            contentSnapshot = "private snapshot", reporterName = reporter.name, reportedMemberName = owner.name)
        whenever(members.findById(2L)).thenReturn(Optional.of(owner))
        whenever(members.findMemberWithTeamForUpdate(1L)).thenReturn(Optional.of(reporter))
        whenever(members.findMemberWithTeamForUpdate(2L)).thenReturn(Optional.of(owner))
        whenever(repository.findFirstByReporterIdAndTargetTypeAndTargetIdAndStatus(1L, request.targetType, "2", ReportStatus.OPEN))
            .thenReturn(report)

        assertThat(service.createReport(1L, request, actor).isNew).isFalse()
        assertThat(service.createReport(1L, request).isNew).isFalse()

        verify(blockService).block(1L, 2L, actor = actor.toAuditActor())
        verify(blockService).block(1L, 2L, actor = reporter.toAuditActor())
        verifyNoMoreInteractions(blockService)
    }

    @Test
    fun `creation and withdrawal audits include IDs and reason without private text or duplicate creation`() {
        val reporter = member(1L, "Reporter")
        val owner = member(2L, "Owner")
        whenever(members.findById(2L)).thenReturn(Optional.of(owner))
        whenever(members.findMemberWithTeamForUpdate(1L)).thenReturn(Optional.of(reporter))
        whenever(members.findMemberWithTeamForUpdate(2L)).thenReturn(Optional.of(owner))
        whenever(repository.save(any<ContentReport>())).thenAnswer { it.getArgument<ContentReport>(0) }
        val actor = LoginMember(id = 1L, name = "Reporter", isImpersonating = true, originalMemberId = 99L)
        val request = CreateReportRequest(ReportTargetType.MEMBER, "2", ReportReason.SPAM, "private report detail")
        val logger = LoggerFactory.getLogger(ReportService::class.java) as Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try {
            val created = service.createReport(1L, request, actor)
            val report = ContentReport(reporter, owner, request.targetType, request.targetId, request.reason,
                request.detail, "private snapshot", reporter.name, owner.name)
            ReflectionTestUtils.setField(report, "id", created.id)
            whenever(repository.findFirstByReporterIdAndTargetTypeAndTargetIdAndStatus(1L, request.targetType, "2", ReportStatus.OPEN))
                .thenReturn(report)
            whenever(repository.findById(created.id)).thenReturn(Optional.of(report))
            service.createReport(1L, request, actor)
            service.cancelReport(1L, created.id, actor)
            val messages = appender.list.map { it.formattedMessage }
            assertThat(messages).hasSize(2)
            assertThat(messages[0]).contains("report.created", created.id.toString(), "SPAM", "\"id\":1", "\"reportedMemberId\":2", "\"originalMemberId\":99")
            assertThat(messages[1]).contains("report.canceled", created.id.toString(), "OPEN", "CANCELED", "\"originalMemberId\":99")
            assertThat(messages.joinToString()).doesNotContain("private report detail", "private snapshot", "private@example.test")
        } finally {
            logger.detachAppender(appender)
        }
    }

    private fun member(id: Long, name: String) = Member(name = name, email = "private@example.test").also {
        ReflectionTestUtils.setField(it, "id", id)
    }
}
