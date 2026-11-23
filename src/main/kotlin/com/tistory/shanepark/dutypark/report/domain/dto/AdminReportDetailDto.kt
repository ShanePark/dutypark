package com.tistory.shanepark.dutypark.report.domain.dto

import com.tistory.shanepark.dutypark.report.domain.entity.ContentReport
import com.tistory.shanepark.dutypark.report.domain.enums.ReportReason
import com.tistory.shanepark.dutypark.report.domain.enums.ReportStatus
import com.tistory.shanepark.dutypark.report.domain.enums.ReportTargetType
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleSnapshot
import java.time.LocalDateTime
import java.util.*

data class AdminReportDetailDto(
    val id: UUID,
    val targetType: ReportTargetType,
    val targetId: String,
    val reason: ReportReason,
    val status: ReportStatus,
    val createdAt: LocalDateTime,
    val reporter: ReportPartyDto?,
    val reportedMember: ReportPartyDto?,
    val reporterName: String,
    val reportedMemberName: String,
    val snapshotPreview: String,
    val detail: String?,
    val contentSnapshot: String,
    val targetExists: Boolean,
    val adminMemo: String?,
    val resolvedAt: LocalDateTime?,
    val resolvedByName: String?,
    val scheduleVersion: Long? = null,
    val scheduleEvidence: String? = null,
    val targetVersionChanged: Boolean = false,
    val currentScheduleVersion: Long? = null,
    val currentScheduleSnapshot: ScheduleSnapshot? = null,
) {
    companion object {
        fun of(report: ContentReport, targetExists: Boolean, resolvedByName: String?, targetVersionChanged: Boolean = false,
               currentScheduleVersion: Long? = null, currentScheduleSnapshot: ScheduleSnapshot? = null): AdminReportDetailDto {
            return AdminReportDetailDto(
                id = report.id,
                targetType = report.targetType,
                targetId = report.targetId,
                reason = report.reason,
                status = report.status,
                createdAt = report.createdDate,
                reporter = ReportPartyDto.of(report.reporter),
                reportedMember = ReportPartyDto.of(report.reportedMember),
                reporterName = report.reporterName,
                reportedMemberName = report.reportedMemberName,
                snapshotPreview = AdminReportSummaryDto.snapshotPreview(report.contentSnapshot),
                detail = report.detail,
                contentSnapshot = report.contentSnapshot,
                targetExists = targetExists,
                adminMemo = report.adminMemo,
                resolvedAt = report.resolvedAt,
                resolvedByName = resolvedByName,
                scheduleVersion = report.scheduleVersion,
                scheduleEvidence = report.scheduleEvidence,
                targetVersionChanged = targetVersionChanged,
                currentScheduleVersion = currentScheduleVersion,
                currentScheduleSnapshot = currentScheduleSnapshot,
            )
        }
    }
}
