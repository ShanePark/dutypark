package com.tistory.shanepark.dutypark.common.exceptions

abstract class DutyparkException(message: String, cause: Throwable?) : RuntimeException(message, cause) {

    abstract val errorCode: Int

}
