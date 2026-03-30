package com.tistory.shanepark.dutypark.duty.batch.domain

import com.fasterxml.jackson.annotation.JsonInclude
import java.time.LocalDate

data class DutyBatchTeamResult(
    val result: Boolean,
    @field:JsonInclude(JsonInclude.Include.NON_NULL)
    val errorCode: String? = null,
    @field:JsonInclude(JsonInclude.Include.NON_NULL)
    val errorDetails: Map<String, Any?>? = null,
    val startDate: LocalDate? = null,
    val endDate: LocalDate? = null,
    val dutyBatchResult: List<Pair<String, DutyBatchResult>> = emptyList(),
) {
    companion object {
        fun success(
            startDate: LocalDate,
            endDate: LocalDate,
            dutyBatchResult: List<Pair<String, DutyBatchResult>>
        ): DutyBatchTeamResult {
            return DutyBatchTeamResult(
                true,
                startDate = startDate,
                endDate = endDate,
                dutyBatchResult = dutyBatchResult
            )
        }

        fun fail(
            errorCode: String,
            errorDetails: Map<String, Any?> = emptyMap(),
        ): DutyBatchTeamResult {
            return DutyBatchTeamResult(
                result = false,
                errorCode = errorCode,
                errorDetails = errorDetails.takeIf { it.isNotEmpty() },
            )
        }
    }
}
