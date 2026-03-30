package com.tistory.shanepark.dutypark.duty.batch.exceptions

class NotSupportedFileException(supportedFile: String) : DutyBatchException(
    errorCode = "dutyBatch.notSupportedFile",
    errorDetails = mapOf("supportedFile" to supportedFile),
)
