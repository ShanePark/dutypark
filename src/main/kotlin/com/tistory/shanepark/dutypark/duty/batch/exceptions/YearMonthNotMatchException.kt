package com.tistory.shanepark.dutypark.duty.batch.exceptions

import java.time.YearMonth

class YearMonthNotMatchException(yearMonth: YearMonth) : DutyBatchException(
    "업로드한 파일의 연월과 현재 설정중인 시간표의 연월이 일치하지 않습니다. 설정중인 시간표: ${yearMonth.year}년 ${yearMonth.monthValue}월"
)
