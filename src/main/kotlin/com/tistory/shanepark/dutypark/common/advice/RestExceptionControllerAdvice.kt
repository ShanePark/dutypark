package com.tistory.shanepark.dutypark.common.advice

import com.tistory.shanepark.dutypark.common.domain.dto.DutyParkErrorResponse
import com.tistory.shanepark.dutypark.common.domain.dto.DutyParkFieldError
import com.tistory.shanepark.dutypark.common.exceptions.DutyparkException
import org.springframework.core.Ordered
import org.springframework.core.annotation.Order
import org.springframework.http.ResponseEntity
import org.springframework.http.converter.HttpMessageNotReadableException
import org.springframework.web.bind.MethodArgumentNotValidException
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.ResponseBody
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.bind.annotation.RestControllerAdvice
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException

@RestControllerAdvice(annotations = [RestController::class])
@Order(Ordered.HIGHEST_PRECEDENCE)
class RestExceptionControllerAdvice {

    private val codePattern = Regex("^[a-z][a-zA-Z0-9]*(\\.[a-zA-Z0-9]+)+$")

    @ResponseBody
    @ExceptionHandler
    fun dutyparkExceptionHandler(e: DutyparkException): ResponseEntity<DutyParkErrorResponse> {
        val defaultCode = when (e.errorCode) {
            401 -> "auth.unauthorized"
            404 -> "common.notFound"
            429 -> "common.rateLimit.exceeded"
            else -> "common.badRequest"
        }
        return errorResponse(
            status = e.errorCode,
            code = normalizeCode(e.message, defaultCode),
        )
    }

    @ResponseBody
    @ExceptionHandler
    fun noSuchElementHandler(e: NoSuchElementException): ResponseEntity<DutyParkErrorResponse> {
        return errorResponse(
            status = 404,
            code = normalizeCode(e.message, "common.notFound"),
        )
    }

    @ResponseBody
    @ExceptionHandler
    fun illegalArgumentHandler(e: IllegalArgumentException): ResponseEntity<DutyParkErrorResponse> {
        return errorResponse(
            status = 400,
            code = normalizeCode(e.message, "common.badRequest"),
        )
    }

    @ResponseBody
    @ExceptionHandler
    fun methodArgumentTypeMismatchHandler(e: MethodArgumentTypeMismatchException): ResponseEntity<DutyParkErrorResponse> {
        return errorResponse(status = 400, code = "common.badRequest")
    }

    @ResponseBody
    @ExceptionHandler
    fun methodArgumentNotValidHandler(e: MethodArgumentNotValidException): ResponseEntity<DutyParkErrorResponse> {
        val fieldErrors = e.bindingResult.fieldErrors.map {
            DutyParkFieldError(
                field = it.field,
                code = normalizeCode(it.defaultMessage, "common.validation.failed"),
            )
        }
        val globalCode = normalizeCode(
            e.bindingResult.globalErrors.firstOrNull()?.defaultMessage,
            "common.validation.failed",
        )
        val code = fieldErrors.firstOrNull()?.code ?: globalCode
        return errorResponse(
            status = 400,
            code = code,
            fieldErrors = fieldErrors,
        )
    }

    @ResponseBody
    @ExceptionHandler
    fun httpMessageNotReadableHandler(e: HttpMessageNotReadableException): ResponseEntity<DutyParkErrorResponse> {
        return errorResponse(status = 400, code = "common.badRequest")
    }

    private fun errorResponse(
        status: Int,
        code: String,
        details: Map<String, Any?> = emptyMap(),
        fieldErrors: List<DutyParkFieldError> = emptyList(),
    ): ResponseEntity<DutyParkErrorResponse> {
        return ResponseEntity.status(status)
            .body(DutyParkErrorResponse.of(status, code, details, fieldErrors))
    }

    private fun normalizeCode(candidate: String?, defaultCode: String): String {
        val value = candidate?.trim().orEmpty()
        if (value.isBlank()) {
            return defaultCode
        }
        return if (codePattern.matches(value)) value else defaultCode
    }
}
