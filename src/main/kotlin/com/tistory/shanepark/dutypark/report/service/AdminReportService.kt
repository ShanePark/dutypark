package com.tistory.shanepark.dutypark.report.service

import com.tistory.shanepark.dutypark.common.exceptions.BadRequestException
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
import com.tistory.shanepark.dutypark.todo.domain.entity.Todo
import com.tistory.shanepark.dutypark.todo.repository.TodoRepository
import com.tistory.shanepark.dutypark.todo.service.TodoService
import org.springframework.data.domain.Page
import org.springframework.data.domain.PageRequest
import org.springframework.data.domain.Pageable
import org.springframework.data.domain.Sort
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDateTime
import java.util.*

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
    ): AdminReportDetailDto {
        if (request.status == ReportStatus.OPEN) {
            throw BadRequestException()
        }
        val report = findReportOrThrow(reportId)
        report.status = request.status
        request.memo?.let { report.adminMemo = it.ifBlank { null } }
        report.resolvedAt = LocalDateTime.now()
        report.resolvedBy = adminMemberId

        return toDetail(report, targetExists = targetExists(report))
    }

    /**
     * Idempotent: a target that is already gone leaves the report untouched and still answers 200.
     * The report itself is kept as the record of the moderation decision.
     */
    @Transactional
    fun deleteTarget(reportId: UUID): AdminReportDetailDto {
        val report = findReportOrThrow(reportId)
        when (report.targetType) {
            ReportTargetType.MEMBER -> throw BadRequestException("report.target.notDeletable")
            ReportTargetType.SCHEDULE -> findSchedule(report.targetId)?.let(scheduleService::deleteScheduleInternal)
            ReportTargetType.TODO -> findTodo(report.targetId)?.let(todoService::deleteTodoInternal)
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
