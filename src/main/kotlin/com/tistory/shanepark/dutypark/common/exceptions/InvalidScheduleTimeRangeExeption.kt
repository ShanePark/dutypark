package com.tistory.shanepark.dutypark.common.exceptions

class InvalidScheduleTimeRangeExeption(message: String = "StartDateTime must not be after EndDateTime") :
    DutyparkException(message, null) {
    override val errorCode: Int = 400
}
