package com.tistory.shanepark.dutypark.security.oauth.mobile

import com.tistory.shanepark.dutypark.common.exceptions.DutyparkException

class MobileOAuthNativeException(
    message: String,
    override val errorCode: Int = 400,
    cause: Throwable? = null,
) : DutyparkException(message, cause)
