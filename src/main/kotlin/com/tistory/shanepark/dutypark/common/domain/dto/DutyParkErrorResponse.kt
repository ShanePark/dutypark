package com.tistory.shanepark.dutypark.common.domain.dto

import com.fasterxml.jackson.annotation.JsonInclude

data class DutyParkFieldError(
    val field: String,
    val code: String,
)

data class DutyParkErrorResponse(
    val status: Int,
    val code: String,
    @field:JsonInclude(JsonInclude.Include.NON_NULL)
    val details: Map<String, Any?>? = null,
    @field:JsonInclude(JsonInclude.Include.NON_EMPTY)
    val fieldErrors: List<DutyParkFieldError> = emptyList(),
) {
    companion object {
        fun of(
            status: Int,
            code: String,
            details: Map<String, Any?> = emptyMap(),
            fieldErrors: List<DutyParkFieldError> = emptyList(),
        ): DutyParkErrorResponse {
            return DutyParkErrorResponse(
                status = status,
                code = code,
                details = details.takeIf { it.isNotEmpty() },
                fieldErrors = fieldErrors,
            )
        }
    }
}
