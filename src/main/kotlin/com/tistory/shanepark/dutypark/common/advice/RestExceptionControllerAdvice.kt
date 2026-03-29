package com.tistory.shanepark.dutypark.common.advice

import com.tistory.shanepark.dutypark.common.config.LocalizedMessageResolver
import com.tistory.shanepark.dutypark.common.domain.dto.DutyParkErrorResponse
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.common.exceptions.RateLimitException
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
class RestExceptionControllerAdvice(
    private val localizedMessageResolver: LocalizedMessageResolver,
) {

    @ResponseBody
    @ExceptionHandler
    fun notAuthorizedHandler(e: AuthException): ResponseEntity<DutyParkErrorResponse> {
        return ResponseEntity.status(e.errorCode)
            .body(
                DutyParkErrorResponse.of(
                    e = e,
                    message = localizedMessageResolver.resolve(e.message, defaultCode = "auth.unauthorized")
                )
            )
    }

    @ResponseBody
    @ExceptionHandler
    fun rateLimitHandler(e: RateLimitException): ResponseEntity<Map<String, String>> {
        return ResponseEntity.status(e.errorCode)
            .body(mapOf("error" to localizedMessageResolver.resolve(e.message, defaultCode = "common.rateLimit.exceeded")))
    }

    @ExceptionHandler
    fun noSuchElementHandler(e: NoSuchElementException): ResponseEntity<Map<String, String>> {
        return ResponseEntity.status(404)
            .body(
                mapOf(
                    "error" to localizedMessageResolver.resolve("common.notFound.title"),
                    "message" to localizedMessageResolver.resolve(e.message, defaultCode = "common.notFound.message")
                )
            )
    }

    @ResponseBody
    @ExceptionHandler
    fun illegalArgumentHandler(e: IllegalArgumentException): ResponseEntity<Map<String, String>> {
        return ResponseEntity.badRequest()
            .body(mapOf("error" to localizedMessageResolver.resolve(e.message, defaultCode = "common.badRequest")))
    }

    @ResponseBody
    @ExceptionHandler
    fun methodArgumentTypeMismatchHandler(e: MethodArgumentTypeMismatchException): ResponseEntity<Map<String, String>> {
        return ResponseEntity.badRequest()
            .body(mapOf("error" to localizedMessageResolver.resolve("common.badRequest")))
    }

    @ResponseBody
    @ExceptionHandler
    fun methodArgumentNotValidHandler(e: MethodArgumentNotValidException): ResponseEntity<Map<String, String>> {
        val message = e.bindingResult.fieldErrors.firstOrNull()?.defaultMessage
            ?: e.bindingResult.globalErrors.firstOrNull()?.defaultMessage
        return ResponseEntity.badRequest()
            .body(mapOf("error" to localizedMessageResolver.resolve(message, defaultCode = "common.validation.failed")))
    }

    @ResponseBody
    @ExceptionHandler
    fun httpMessageNotReadableHandler(e: HttpMessageNotReadableException): ResponseEntity<Map<String, String>> {
        return ResponseEntity.badRequest()
            .body(mapOf("error" to localizedMessageResolver.resolve("common.badRequest")))
    }
}
