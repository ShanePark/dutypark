package com.tistory.shanepark.dutypark.report.domain.dto

import com.tistory.shanepark.dutypark.report.domain.entity.ContentReport
import com.tistory.shanepark.dutypark.report.domain.enums.ReportReason
import com.tistory.shanepark.dutypark.report.domain.enums.ReportStatus
import com.tistory.shanepark.dutypark.report.domain.enums.ReportTargetType
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
) {
    companion object {
        fun of(report: ContentReport, targetExists: Boolean, resolvedByName: String?): AdminReportDetailDto {
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
            )
        }
    }
}
