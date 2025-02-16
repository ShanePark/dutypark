package com.tistory.shanepark.dutypark.duty.batch.exceptions

open class DutyBatchException(errorMessage: String) : RuntimeException(errorMessage) {
    val batchErrorMessage: String = errorMessage
}
