package com.tistory.shanepark.dutypark.duty.batch.exceptions

import java.time.YearMonth

class YearMonthNotMatchException(yearMonth: YearMonth) : DutyBatchException(
    errorCode = "dutyBatch.yearMonthNotMatch",
    errorDetails = mapOf(
        "year" to yearMonth.year,
        "month" to yearMonth.monthValue,
    ),
)
