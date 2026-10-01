package com.tistory.shanepark.dutypark.report.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.BadRequestException
import com.tistory.shanepark.dutypark.common.logging.AuditActor
import com.tistory.shanepark.dutypark.common.logging.auditEventAfterCommit
import com.tistory.shanepark.dutypark.common.logging.toAuditActor
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.report.domain.dto.AdminReportDetailDto
import com.tistory.shanepark.dutypark.report.domain.dto.AdminReportSummaryDto
import com.tistory.shanepark.dutypark.report.domain.dto.UpdateReportStatusRequest
import com.tistory.shanepark.dutypark.report.domain.entity.ContentReport
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
import java.util.*
import org.springframework.data.domain.Page
import org.springframework.data.domain.PageRequest
import org.springframework.data.domain.Pageable
import org.springframework.data.domain.Sort
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

/**
 * Moderation of submitted reports. Content is removed through the internal delete methods of the
 * owning services, which skip the permission checks that only apply to the content owner.
 */
@Service
@Transactional(readOnly = true)
class AdminReportService(
    private val contentReportRepository: ContentReportRepository,
    private val memberRepository: MemberRepository,
    private val scheduleRepository: ScheduleRepository,
    private val todoRepository: TodoRepository,
    private val scheduleService: ScheduleService,
    private val todoService: TodoService,
) {

    private val log = logger()

    fun findReports(status: ReportStatus?, pageable: Pageable): Page<AdminReportSummaryDto> {
        val newestFirst = PageRequest.of(pageable.pageNumber, pageable.pageSize, NEWEST_FIRST)
        val page = if (status == null) {
            contentReportRepository.findAll(newestFirst)
        } else {
            contentReportRepository.findAllByStatus(status, newestFirst)
        }
        return page.map(AdminReportSummaryDto::of)
    }

    fun findReport(reportId: UUID): AdminReportDetailDto {
        val report = findReportOrThrow(reportId)
        return toDetail(report, targetExists = targetExists(report))
    }

    @Transactional
    fun updateStatus(
        reportId: UUID,
        adminMemberId: Long,
        request: UpdateReportStatusRequest,
        loginMember: LoginMember? = null,
    ): AdminReportDetailDto {
        // 신고는 다시 열지 못하고, CANCELED 는 신고자 본인만 남길 수 있는 상태다.
        if (request.status == ReportStatus.OPEN || request.status == ReportStatus.CANCELED) {
            throw BadRequestException()
        }
        val report = findReportOrThrow(reportId)
        val previousStatus = report.status
        val previousMemo = report.adminMemo
        if (report.status != request.status) {
            report.status = request.status
            report.resolvedAt = LocalDateTime.now()
            report.resolvedBy = adminMemberId
        }
        request.memo?.let { report.adminMemo = it.ifBlank { null } }
        if (previousStatus != report.status || previousMemo != report.adminMemo) {
            log.auditEventAfterCommit(
                "report.moderated", loginMember?.toAuditActor() ?: AuditActor(adminMemberId, "unknown"),
                target = mapOf("reportId" to report.id, "targetType" to report.targetType, "targetId" to report.targetId),
                details = mapOf(
                    "statusBefore" to previousStatus,
                    "statusAfter" to report.status,
                    "memoChanged" to (previousMemo != report.adminMemo),
                ),
            )
        }

        return toDetail(report, targetExists = targetExists(report))
    }

    /**
     * Idempotent: a target that is already gone leaves the report untouched and still answers 200.
     * The report itself is kept as the record of the moderation decision.
     */
    @Transactional
    fun deleteTarget(reportId: UUID, loginMember: LoginMember? = null): AdminReportDetailDto {
        val report = findReportOrThrow(reportId)
        val actor = loginMember?.toAuditActor()
        var deleted = false
        when (report.targetType) {
            ReportTargetType.MEMBER -> throw BadRequestException("report.target.notDeletable")
            ReportTargetType.SCHEDULE -> findSchedule(report.targetId)?.let {
                scheduleService.deleteScheduleInternal(it, actor = actor)
                deleted = true
            }
            ReportTargetType.TODO -> findTodo(report.targetId)?.let { todo ->
                todoService.deleteTodoInternal(todo, actor = actor)
                deleted = true
            }
        }
        if (deleted) {
            log.auditEventAfterCommit(
                "report.target_deleted", actor,
                target = mapOf("reportId" to report.id, "targetType" to report.targetType, "targetId" to report.targetId),
                details = mapOf("reason" to report.reason, "status" to report.status),
            )
        }
        return toDetail(report, targetExists = false)
    }

    private fun findReportOrThrow(reportId: UUID): ContentReport {
        return contentReportRepository.findById(reportId).orElseThrow()
    }

    private fun toDetail(report: ContentReport, targetExists: Boolean): AdminReportDetailDto {
        val resolvedByName = report.resolvedBy?.let { memberRepository.findById(it).orElse(null)?.name }
        return AdminReportDetailDto.of(report, targetExists = targetExists, resolvedByName = resolvedByName)
    }

    private fun targetExists(report: ContentReport): Boolean {
        return when (report.targetType) {
            ReportTargetType.MEMBER -> report.targetId.toLongOrNull()?.let(memberRepository::existsById) == true
            ReportTargetType.SCHEDULE -> findSchedule(report.targetId) != null
            ReportTargetType.TODO -> findTodo(report.targetId) != null
        }
    }

    private fun findSchedule(targetId: String): Schedule? {
        return toUuid(targetId)?.let { scheduleRepository.findById(it).orElse(null) }
    }

    private fun findTodo(targetId: String): Todo? {
        return toUuid(targetId)?.let { todoRepository.findById(it).orElse(null) }
    }

    private fun toUuid(targetId: String): UUID? = runCatching { UUID.fromString(targetId) }.getOrNull()

    companion object {
        /** The id is a monotonic ULID, so it breaks ties on equal timestamps and keeps paging stable. */
        private val NEWEST_FIRST = Sort.by(Sort.Direction.DESC, "createdDate", "id")
    }

}
