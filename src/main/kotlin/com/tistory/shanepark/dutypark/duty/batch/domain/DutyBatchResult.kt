package com.tistory.shanepark.dutypark.duty.batch.domain

import com.fasterxml.jackson.annotation.JsonInclude
import java.time.LocalDate

data class DutyBatchResult(
    val result: Boolean,
    @field:JsonInclude(JsonInclude.Include.NON_NULL)
    val errorCode: String? = null,
    @field:JsonInclude(JsonInclude.Include.NON_NULL)
    val errorDetails: Map<String, Any?>? = null,
    val startDate: LocalDate? = null,
    val endDate: LocalDate? = null,
    val workingDays: Int = 0,
    val offDays: Int = 0,
) {
    companion object {
        fun success(workingDays: Int, offDays: Int, startDate: LocalDate, endDate: LocalDate): DutyBatchResult {
            return DutyBatchResult(
                true,
                workingDays = workingDays,
                offDays = offDays,
                startDate = startDate,
                endDate = endDate
            )
        }

        fun fail(
            errorCode: String?,
            errorDetails: Map<String, Any?> = emptyMap(),
        ): DutyBatchResult {
            return DutyBatchResult(
                result = false,
                errorCode = errorCode,
                errorDetails = errorDetails.takeIf { it.isNotEmpty() },
            )
        }
    }
}
