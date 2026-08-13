package com.tistory.shanepark.dutypark.security.oauth.apple

import com.tistory.shanepark.dutypark.common.exceptions.DutyparkException

class AppleOAuthException(
    message: String,
    override val errorCode: Int = 401,
    cause: Throwable? = null,
) : DutyparkException(message, cause)
