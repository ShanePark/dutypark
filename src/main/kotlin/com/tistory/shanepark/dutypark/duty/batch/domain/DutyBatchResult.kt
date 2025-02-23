package com.tistory.shanepark.dutypark.duty.batch.domain

import java.time.LocalDate

data class DutyBatchResult(
    val result: Boolean,
    val errorMessage: String = "",
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

        fun fail(errorMessage: String): DutyBatchResult {
            return DutyBatchResult(result = false, errorMessage = errorMessage)
        }
    }
}
