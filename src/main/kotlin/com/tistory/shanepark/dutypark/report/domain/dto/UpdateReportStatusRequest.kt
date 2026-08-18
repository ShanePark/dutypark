package com.tistory.shanepark.dutypark.report.domain.dto

import com.tistory.shanepark.dutypark.report.domain.enums.ReportStatus
import jakarta.validation.constraints.NotNull
import jakarta.validation.constraints.Size

data class UpdateReportStatusRequest(
    /** Only [ReportStatus.RESOLVED] and [ReportStatus.DISMISSED] are accepted: a report cannot be reopened. */
    @field:NotNull
    val status: ReportStatus,

    /** Omit (or send null) to keep the memo already recorded; send a blank string to clear it. */
    @field:Size(max = 1000)
    val memo: String? = null,
)
