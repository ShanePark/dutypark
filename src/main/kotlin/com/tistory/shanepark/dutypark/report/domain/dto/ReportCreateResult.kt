package com.tistory.shanepark.dutypark.report.domain.dto

import java.util.*

/**
 * [isNew] is false when an OPEN report by the same reporter for the same target already existed,
 * which the controller maps to 200 instead of 201.
 */
data class ReportCreateResult(
    val id: UUID,
    val isNew: Boolean,
)
