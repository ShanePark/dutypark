package com.tistory.shanepark.dutypark.report.domain.dto

import com.tistory.shanepark.dutypark.report.domain.entity.ContentReport
import com.tistory.shanepark.dutypark.report.domain.enums.ReportReason
import com.tistory.shanepark.dutypark.report.domain.enums.ReportStatus
import com.tistory.shanepark.dutypark.report.domain.enums.ReportTargetType
import java.time.LocalDateTime
import java.util.*

data class AdminReportSummaryDto(
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
) {
    companion object {
        private const val SNAPSHOT_PREVIEW_LENGTH = 100

        fun of(report: ContentReport): AdminReportSummaryDto {
            return AdminReportSummaryDto(
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
                snapshotPreview = snapshotPreview(report.contentSnapshot),
            )
        }

        fun snapshotPreview(contentSnapshot: String): String {
            return contentSnapshot.lineSequence().firstOrNull().orEmpty().take(SNAPSHOT_PREVIEW_LENGTH)
        }
    }
}
