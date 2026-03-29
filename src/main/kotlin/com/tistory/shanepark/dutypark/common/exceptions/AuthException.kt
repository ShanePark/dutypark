package com.tistory.shanepark.dutypark.common.exceptions

class AuthException(message: String = "auth.unauthorized") :
    DutyparkException(message, null) {
    override val errorCode: Int = 401
}
