package com.tistory.shanepark.dutypark.security.interceptor

import com.tistory.shanepark.dutypark.security.service.AuthService
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.springframework.web.servlet.HandlerInterceptor

class AuthInterceptor(
    private val authService: AuthService
) : HandlerInterceptor {
    private val log: Logger = LoggerFactory.getLogger(AuthInterceptor::class.java)

    override fun preHandle(request: HttpServletRequest, response: HttpServletResponse, handler: Any): Boolean {
        request.getHeader("Authorization")?.let {
            val loginMember = authService.findLoginMemberByToken(it)
            request.setAttribute("loginMember", loginMember)
            log.info("Authorization: $it")
            log.info("loginMember: $loginMember")
        }
        return true
    }

}
