package com.tistory.shanepark.dutypark.common.exceptions

class ForbiddenException(message: String) : DutyparkException(message, null) {
    override val errorCode: Int = 403
}
