package com.tistory.shanepark.dutypark.common.exceptions

class RateLimitException(
    message: String = "Too many requests"
) : DutyparkException(message, null) {

    override val errorCode: Int = 429

}
