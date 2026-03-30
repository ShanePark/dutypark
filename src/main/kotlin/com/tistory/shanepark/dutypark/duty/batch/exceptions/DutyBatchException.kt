package com.tistory.shanepark.dutypark.duty.batch.exceptions

open class DutyBatchException(
    val errorCode: String,
    val errorDetails: Map<String, Any?> = emptyMap(),
) : RuntimeException(errorCode)
