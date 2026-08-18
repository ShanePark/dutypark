package com.tistory.shanepark.dutypark.report.domain.dto

import com.tistory.shanepark.dutypark.report.domain.enums.ReportReason
import com.tistory.shanepark.dutypark.report.domain.enums.ReportTargetType
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.NotNull
import jakarta.validation.constraints.Size

data class CreateReportRequest(
    @field:NotNull
    val targetType: ReportTargetType,

    @field:NotBlank
    val targetId: String,

    @field:NotNull
    val reason: ReportReason,

    @field:Size(max = 500)
    val detail: String? = null,

    val alsoBlock: Boolean = false,
)
