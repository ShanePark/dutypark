package com.tistory.shanepark.dutypark.duty.batch.exceptions

class MultipleNameFoundException(names: List<String>) :
    DutyBatchException(
        errorCode = "dutyBatch.multipleNameFound",
        errorDetails = mapOf("names" to names),
    )
