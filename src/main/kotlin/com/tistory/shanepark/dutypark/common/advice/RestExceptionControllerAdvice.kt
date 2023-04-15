package com.tistory.shanepark.dutypark.common.advice

import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import org.springframework.core.Ordered
import org.springframework.core.annotation.Order
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*

@ControllerAdvice(annotations = [RestController::class])
@Order(Ordered.HIGHEST_PRECEDENCE)
class RestExceptionControllerAdvice {

    @ResponseBody
    @ExceptionHandler
    fun notAuthorizedHandler(e: DutyparkAuthException): ResponseEntity<Any> {
        return ResponseEntity.status(e.errorCode).build()
    }

}
