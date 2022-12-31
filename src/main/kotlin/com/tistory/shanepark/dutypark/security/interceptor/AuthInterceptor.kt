package com.tistory.shanepark.dutypark.security.interceptor

import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.springframework.web.servlet.HandlerInterceptor

class AuthInterceptor : HandlerInterceptor {
    private val log: Logger = LoggerFactory.getLogger(AuthInterceptor::class.java)

    override fun preHandle(request: HttpServletRequest, response: HttpServletResponse, handler: Any): Boolean {
        log.info("AuthInterceptor preHandle")
        return super.preHandle(request, response, handler)
    }

}
