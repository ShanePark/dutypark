package com.tistory.shanepark.dutypark.report.domain.dto

import com.tistory.shanepark.dutypark.report.domain.entity.ContentReport
import com.tistory.shanepark.dutypark.report.domain.enums.ReportReason
import com.tistory.shanepark.dutypark.report.domain.enums.ReportStatus
import com.tistory.shanepark.dutypark.report.domain.enums.ReportTargetType
import java.time.LocalDateTime
import java.util.UUID

/**
 * 신고자 본인에게 보여주는 신고 DTO. 관리자 전용 정보(adminMemo, resolvedBy, contentSnapshot)와
 * 신고 대상 식별자는 절대 담지 않는다. 대상 이름은 신고 시점 스냅샷이라 상대가 탈퇴해도 남는다.
 */
data class MyReportDto(
    val id: UUID,
    val targetType: ReportTargetType,
    val reportedMemberName: String,
    val reason: ReportReason,
    val detail: String?,
    val status: ReportStatus,
    val createdAt: LocalDateTime,
    val resolvedAt: LocalDateTime?,
) {
    companion object {
        fun of(report: ContentReport): MyReportDto {
            return MyReportDto(
                id = report.id,
                targetType = report.targetType,
                reportedMemberName = report.reportedMemberName,
                reason = report.reason,
                detail = report.detail,
                status = report.status,
                createdAt = report.createdDate,
                resolvedAt = report.resolvedAt,
            )
        }
    }
}
