package com.tistory.shanepark.dutypark.common.advice

import com.tistory.shanepark.dutypark.common.domain.dto.DutyParkErrorResponse
import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import org.hibernate.query.sqm.tree.SqmNode.log
import org.springframework.core.Ordered
import org.springframework.core.annotation.Order
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*

@RestControllerAdvice(annotations = [RestController::class])
@Order(Ordered.HIGHEST_PRECEDENCE)
class RestExceptionControllerAdvice {

    @ResponseBody
    @ExceptionHandler
    fun notAuthorizedHandler(e: DutyparkAuthException): ResponseEntity<Any> {
        return ResponseEntity.status(e.errorCode)
            .body(DutyParkErrorResponse.of(e))
    }

    @ExceptionHandler
    fun noSuchElementHandler(e: NoSuchElementException): ResponseEntity<Any> {
        log.warn("no such element: ${e.message}")
        return ResponseEntity.status(404).build()
    }

}
