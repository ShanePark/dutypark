package com.tistory.shanepark.dutypark.common.advice

import com.tistory.shanepark.dutypark.common.exceptions.AuthenticationException
import org.springframework.core.Ordered
import org.springframework.core.annotation.Order
import org.springframework.web.bind.annotation.ControllerAdvice
import org.springframework.web.bind.annotation.ExceptionHandler

@ControllerAdvice(annotations = [org.springframework.stereotype.Controller::class])
@Order(Ordered.LOWEST_PRECEDENCE)
class ViewExceptionControllerAdvice {

    @ExceptionHandler
    fun notAuthorizedHandler(e: AuthenticationException): String {
        return "redirect:/login"
    }

}