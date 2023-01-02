package com.tistory.shanepark.dutypark.common.advice

import com.tistory.shanepark.dutypark.common.exceptions.AuthenticationException
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.ControllerAdvice
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.ResponseBody
import org.springframework.web.bind.annotation.ResponseStatus

@ControllerAdvice
class ExceptionControllerAdvice {

    @ResponseStatus(HttpStatus.OK)
    @ResponseBody
    @ExceptionHandler
    fun notAuthorizedHandler(e: AuthenticationException): ResponseEntity<Any> {
        return ResponseEntity.status(e.errorCode).build()
    }

}
