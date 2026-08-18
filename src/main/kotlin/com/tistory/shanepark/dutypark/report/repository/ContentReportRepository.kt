package com.tistory.shanepark.dutypark.report.repository

import com.tistory.shanepark.dutypark.report.domain.entity.ContentReport
import com.tistory.shanepark.dutypark.report.domain.enums.ReportStatus
import com.tistory.shanepark.dutypark.report.domain.enums.ReportTargetType
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.JpaRepository
import java.util.*

interface ContentReportRepository : JpaRepository<ContentReport, UUID> {

    fun findFirstByReporterIdAndTargetTypeAndTargetIdAndStatus(
        reporterId: Long,
        targetType: ReportTargetType,
        targetId: String,
        status: ReportStatus,
    ): ContentReport?

    fun findAllByStatus(status: ReportStatus, pageable: Pageable): Page<ContentReport>

}
