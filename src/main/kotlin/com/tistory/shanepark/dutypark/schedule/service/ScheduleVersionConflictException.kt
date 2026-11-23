package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.common.exceptions.DutyparkException

class ScheduleVersionConflictException : DutyparkException("schedule.version.conflict", null) {
    override val errorCode: Int = 409
}
