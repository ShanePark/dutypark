package com.tistory.shanepark.dutypark.common.exceptions

class RateLimitException(
    message: String = "common.rateLimit.exceeded"
) : DutyparkException(message, null) {

    override val errorCode: Int = 429

}
