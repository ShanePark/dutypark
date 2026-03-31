package com.tistory.shanepark.dutypark.common.exceptions

class BadRequestException(message: String = "common.badRequest") :
    DutyparkException(message, null) {
    override val errorCode: Int = 400
}
