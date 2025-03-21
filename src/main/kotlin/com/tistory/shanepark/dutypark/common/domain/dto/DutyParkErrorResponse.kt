package com.tistory.shanepark.dutypark.common.domain.dto

import com.tistory.shanepark.dutypark.common.exceptions.AuthException

data class DutyParkErrorResponse(
    val errorCode: Int,
    val message: String,
) {
    companion object {
        fun of(e: AuthException): DutyParkErrorResponse {
            return DutyParkErrorResponse(
                errorCode = e.errorCode,
                message = e.message ?: "Unknown Error"
            )
        }
    }
}
