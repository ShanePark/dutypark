package com.tistory.shanepark.dutypark.common.domain.dto

import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException

data class DutyParkErrorResponse(
    val errorCode: Int,
    val message: String,
) {
    companion object {
        fun of(e: DutyparkAuthException): DutyParkErrorResponse {
            return DutyParkErrorResponse(
                errorCode = e.errorCode,
                message = e.message ?: "Unknown Error"
            )
        }
    }
}
