package com.tistory.shanepark.dutypark.report.service

import ch.qos.logback.classic.Logger
import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.core.read.ListAppender
import com.tistory.shanepark.dutypark.common.logging.toAuditActor
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.report.domain.dto.UpdateReportStatusRequest
import com.tistory.shanepark.dutypark.report.domain.entity.ContentReport
import com.tistory.shanepark.dutypark.report.domain.enums.ReportReason
import com.tistory.shanepark.dutypark.report.domain.enums.ReportStatus
import com.tistory.shanepark.dutypark.report.domain.enums.ReportTargetType
import com.tistory.shanepark.dutypark.report.repository.ContentReportRepository
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.schedule.service.ScheduleService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.todo.domain.entity.Todo
import com.tistory.shanepark.dutypark.todo.repository.TodoRepository
import com.tistory.shanepark.dutypark.todo.service.TodoService
import java.time.LocalDateTime
import java.util.Optional
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.slf4j.LoggerFactory

class AdminReportServiceTest {
    private val contentReportRepository: ContentReportRepository = mock()
    private val memberRepository: MemberRepository = mock()
    private val scheduleRepository: ScheduleRepository = mock()
    private val todoRepository: TodoRepository = mock()
    private val scheduleService: ScheduleService = mock()
    private val todoService: TodoService = mock()
    private val service = AdminReportService(
        contentReportRepository,
        memberRepository,
        scheduleRepository,
        todoRepository,
        scheduleService,
        todoService,
    )

    @Test
    fun `target deletion audit correlates report and moderator and omits already absent targets`() {
        val actor = LoginMember(id = 5L, name = "Admin", isImpersonating = true, originalMemberId = 9L)
        val todo = Todo(member = Member(name = "Owner"), title = "private title", content = "private content", position = 0)
        val report = report(ReportTargetType.TODO, todo.id.toString())
        whenever(contentReportRepository.findById(report.id)).thenReturn(Optional.of(report))
        whenever(todoRepository.findById(todo.id)).thenReturn(Optional.of(todo), Optional.empty())
        val logger = LoggerFactory.getLogger(AdminReportService::class.java) as Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try {
            service.deleteTarget(report.id, actor)
            service.deleteTarget(report.id, actor)
            assertThat(appender.list).hasSize(1)
            assertThat(appender.list.single().formattedMessage).contains("report.target_deleted", report.id.toString(),
                todo.id.toString(), "\"id\":5", "\"originalMemberId\":9", "SPAM")
                .doesNotContain("private title", "private content", "Reported content")
            verify(todoService).deleteTodoInternal(todo, actor = actor.toAuditActor())
        } finally {
            logger.detachAppender(appender)
        }
    }

    @Test
    fun `moderation audit records status change without private memo or content and omits no op`() {
        val report = report(ReportTargetType.MEMBER, "1")
        whenever(contentReportRepository.findById(report.id)).thenReturn(Optional.of(report))
        val logger = LoggerFactory.getLogger(AdminReportService::class.java) as Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try {
            val request = UpdateReportStatusRequest(
                status = ReportStatus.DISMISSED,
                memo = "private moderation memo",
            )
            service.updateStatus(report.id, 99L, request)
            service.updateStatus(report.id, 99L, request)
            val messages = appender.list.map { it.formattedMessage }
            assertThat(messages).hasSize(1)
            assertThat(messages.single()).contains("report.moderated", report.id.toString(), "\"id\":99", "OPEN", "DISMISSED")
                .doesNotContain("private moderation memo", "Reported content")
        } finally {
            logger.detachAppender(appender)
        }
    }

    @Test
    fun `delete target passes admin identity to schedule and todo attachment cleanup`() {
        val actor = LoginMember(id = 5L, name = "Admin", isImpersonating = true, originalMemberId = 9L)
        val owner = Member(name = "Owner")
        val schedule = Schedule(
            member = owner,
            content = "schedule",
            startDateTime = LocalDateTime.of(2026, 9, 27, 9, 0),
            endDateTime = LocalDateTime.of(2026, 9, 27, 10, 0),
            position = 0,
        )
        val scheduleReport = report(ReportTargetType.SCHEDULE, schedule.id.toString())
        whenever(contentReportRepository.findById(scheduleReport.id)).thenReturn(Optional.of(scheduleReport))
        whenever(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))

        service.deleteTarget(scheduleReport.id, loginMember = actor)

        verify(scheduleService).deleteScheduleInternal(schedule, actor = actor.toAuditActor())

        val todo = Todo(
            member = owner,
            title = "todo",
            content = "content",
            position = 0,
        )
        val todoReport = report(ReportTargetType.TODO, todo.id.toString())
        whenever(contentReportRepository.findById(todoReport.id)).thenReturn(Optional.of(todoReport))
        whenever(todoRepository.findById(todo.id)).thenReturn(Optional.of(todo))

        service.deleteTarget(todoReport.id, loginMember = actor)

        verify(todoService).deleteTodoInternal(todo, actor = actor.toAuditActor())
    }

    private fun report(targetType: ReportTargetType, targetId: String) = ContentReport(
        reporter = null,
        reportedMember = null,
        targetType = targetType,
        targetId = targetId,
        reason = ReportReason.SPAM,
        contentSnapshot = "Reported content",
        reporterName = "Reporter",
        reportedMemberName = "Reported member",
    )
}
