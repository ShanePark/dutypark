package com.tistory.shanepark.dutypark.report.domain.dto

import com.tistory.shanepark.dutypark.report.domain.enums.ReportStatus
import jakarta.validation.constraints.NotNull
import jakarta.validation.constraints.Size

data class UpdateReportStatusRequest(
    /** Only [ReportStatus.RESOLVED] and [ReportStatus.DISMISSED] are accepted: a report cannot be reopened. */
    @field:NotNull
    val status: ReportStatus,

    @field:Size(max = 1000)
    val memo: String? = null,
)
