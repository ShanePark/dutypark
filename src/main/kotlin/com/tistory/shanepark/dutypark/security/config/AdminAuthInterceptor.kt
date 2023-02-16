package com.tistory.shanepark.dutypark.security.config

import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.service.AuthService
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.Logger
import org.springframework.web.servlet.HandlerInterceptor

class AdminAuthInterceptor(
    private val authService: AuthService
) : HandlerInterceptor {
    private val log: Logger = org.slf4j.LoggerFactory.getLogger(AdminAuthInterceptor::class.java)

    override fun preHandle(request: HttpServletRequest, response: HttpServletResponse, handler: Any): Boolean {
        request.getAttribute(LoginMember.attrName)?.let {
            val loginMember = it as LoginMember
            val isAdmin = authService.isAdmin(loginMember)
            if (!isAdmin) {
                log.info("$loginMember is not admin.")
                response.sendError(HttpServletResponse.SC_FORBIDDEN)
            }
            return isAdmin
        }
        response.sendRedirect("/login")
        return false
    }
}
