package com.tistory.shanepark.dutypark.common.exceptions

class AuthenticationException(message: String = "authentication Exception") :
    DutyparkException(message, null) {
    override val errorCode: Int = 401
}
