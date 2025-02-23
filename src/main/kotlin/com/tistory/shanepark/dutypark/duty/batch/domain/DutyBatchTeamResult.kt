package com.tistory.shanepark.dutypark.duty.batch.domain

import java.time.LocalDate

data class DutyBatchTeamResult(
    val result: Boolean,
    val errorMessage: String = "",
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

        fun fail(errorMessage: String): DutyBatchTeamResult {
            return DutyBatchTeamResult(result = false, errorMessage = errorMessage)
        }
    }
}
