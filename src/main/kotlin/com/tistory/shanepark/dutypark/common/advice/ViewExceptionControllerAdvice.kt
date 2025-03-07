package com.tistory.shanepark.dutypark.common.advice

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import jakarta.servlet.http.HttpServletRequest
import org.springframework.core.Ordered
import org.springframework.core.annotation.Order
import org.springframework.stereotype.Controller
import org.springframework.web.bind.annotation.ControllerAdvice
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.servlet.ModelAndView
import java.net.URLEncoder

@ControllerAdvice(annotations = [Controller::class])
@Order(Ordered.HIGHEST_PRECEDENCE)
class ViewExceptionControllerAdvice {
    private val log = logger()

    @ExceptionHandler
    fun notAuthorizedHandler(e: DutyparkAuthException, request: HttpServletRequest): ModelAndView {
        val redirectUrl = "redirect:/auth/login?referer=" + URLEncoder.encode(request.requestURI, "UTF-8")
        return ModelAndView(redirectUrl)
    }

    @ExceptionHandler(java.util.NoSuchElementException::class)
    fun noSuchElementHandler(e: NoSuchElementException): String {
        log.info("no such element: ${e.message}")
        return "error/404"
    }

    @ExceptionHandler(IllegalArgumentException::class)
    fun illegalArgumentExceptionHandler(e: IllegalArgumentException): String {
        log.info("illegal argument: ${e.message}")
        return "error/400"
    }

}
