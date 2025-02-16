package com.tistory.shanepark.dutypark.duty.batch.domain

class DutyBatchResult(
    val result: Boolean,
    val errorMessage: String = "",
    val workingDays: Int = 0,
    val offDays: Int = 0,
) {

    companion object {
        fun success(workingDays: Int, offDays: Int): DutyBatchResult {
            return DutyBatchResult(true, workingDays = workingDays, offDays = offDays)
        }

        fun fail(errorMessage: String): DutyBatchResult {
            return DutyBatchResult(false, errorMessage)
        }
    }
}
