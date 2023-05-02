package com.tistory.shanepark.dutypark.common.advice

import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import org.springframework.core.Ordered
import org.springframework.core.annotation.Order
import org.springframework.web.bind.annotation.ControllerAdvice
import org.springframework.web.bind.annotation.ExceptionHandler

@ControllerAdvice(annotations = [org.springframework.stereotype.Controller::class])
@Order(Ordered.LOWEST_PRECEDENCE)
class ViewExceptionControllerAdvice {

    val log: org.slf4j.Logger = org.slf4j.LoggerFactory.getLogger(this.javaClass)

    @ExceptionHandler
    fun notAuthorizedHandler(e: DutyparkAuthException): String {
        return "redirect:/login"
    }

    @ExceptionHandler
    fun noSuchElementHandler(e: NoSuchElementException): String {
        log.info("no such element: ${e.message}")
        return "error/404"
    }

}
