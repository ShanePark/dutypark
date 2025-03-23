package com.tistory.shanepark.dutypark.common.advice

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import jakarta.servlet.http.HttpServletRequest
import org.springframework.core.Ordered
import org.springframework.core.annotation.Order
import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.ControllerAdvice
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException
import java.net.URLEncoder

@ControllerAdvice(annotations = [Controller::class])
@Order(Ordered.HIGHEST_PRECEDENCE)
class ViewExceptionControllerAdvice {
    private val log = logger()

    @ExceptionHandler(AuthException::class)
    fun notAuthorizedHandler(
        e: AuthException,
        @Login(required = false) login: LoginMember?,
        request: HttpServletRequest, model: Model
    ): String {
        if (login == null) {
            return "redirect:${"/auth/login?referer=" + URLEncoder.encode(request.requestURI, "UTF-8")}"
        }
        log.warn("not authorized $login (ip:${request.remoteAddr}) tried to access [${request.requestURI}]")
        return errorPage(
            model = model,
            errorCode = 401,
            e = e,
            message = "접근 권한이 없습니다.",
        )
    }

    @ExceptionHandler(NoSuchElementException::class)
    fun noSuchElementHandler(e: NoSuchElementException, model: Model): String {
        return errorPage(model = model, errorCode = 404, e = e, message = "존재하지 않는 페이지입니다.")
    }

    @ExceptionHandler(IllegalArgumentException::class, MethodArgumentTypeMismatchException::class)
    fun illegalArgumentExceptionHandler(e: Exception, model: Model): String {
        return errorPage(model = model, errorCode = 400, e = e, message = "잘못된 요청입니다.")
    }

    fun errorPage(
        model: Model,
        errorCode: Int,
        e: Exception,
        message: String? = null,
    ): String {
        log.warn("error: ${e.javaClass.name}, message:${e.message}")
        model.addAttribute("errorMessage", message ?: e.message)
        model.addAttribute("errorCode", errorCode)
        return "error/error"
    }

}
