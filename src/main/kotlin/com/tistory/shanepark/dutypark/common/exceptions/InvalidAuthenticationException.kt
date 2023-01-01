package com.tistory.shanepark.dutypark.common.exceptions

class InvalidAuthenticationException :
    DutyparkException("there is no member match with the input email and password", null) {
    override val errorCode: Int = 401
}
