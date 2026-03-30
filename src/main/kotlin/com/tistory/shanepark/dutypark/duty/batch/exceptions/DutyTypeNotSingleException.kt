package com.tistory.shanepark.dutypark.duty.batch.exceptions

import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType

class DutyTypeNotSingleException(dutyTypes: List<DutyType>) :
    DutyBatchException(
        errorCode = "dutyBatch.dutyTypeNotSingle",
        errorDetails = mapOf(
            "dutyTypeCount" to dutyTypes.size,
            "dutyTypeNames" to dutyTypes.map { it.name },
        ),
    )
