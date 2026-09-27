package com.tistory.shanepark.dutypark.report.service

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.report.domain.entity.ContentReport
import com.tistory.shanepark.dutypark.report.domain.enums.ReportReason
import com.tistory.shanepark.dutypark.report.domain.enums.ReportTargetType
import com.tistory.shanepark.dutypark.report.repository.ContentReportRepository
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.schedule.service.ScheduleService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.common.logging.toAuditActor
import com.tistory.shanepark.dutypark.todo.domain.entity.Todo
import com.tistory.shanepark.dutypark.todo.repository.TodoRepository
import com.tistory.shanepark.dutypark.todo.service.TodoService
import org.junit.jupiter.api.Test
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import java.time.LocalDateTime
import java.util.Optional

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
