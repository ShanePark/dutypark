package com.tistory.shanepark.dutypark.common.advice

import com.tistory.shanepark.dutypark.common.domain.dto.DutyParkErrorResponse
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import org.hibernate.query.sqm.tree.SqmNode.log
import org.springframework.core.Ordered
import org.springframework.core.annotation.Order
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.ResponseBody
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.bind.annotation.RestControllerAdvice

@RestControllerAdvice(annotations = [RestController::class])
@Order(Ordered.HIGHEST_PRECEDENCE)
class RestExceptionControllerAdvice {

    @ResponseBody
    @ExceptionHandler
    fun notAuthorizedHandler(e: AuthException): ResponseEntity<DutyParkErrorResponse> {
        return ResponseEntity.status(e.errorCode)
            .body(DutyParkErrorResponse.of(e))
    }

    @ExceptionHandler
    fun noSuchElementHandler(e: NoSuchElementException): ResponseEntity<Void> {
        log.warn("no such element: ${e.message}")
        return ResponseEntity.status(404).build()
    }

}
