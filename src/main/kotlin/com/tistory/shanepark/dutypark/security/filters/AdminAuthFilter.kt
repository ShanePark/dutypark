package com.tistory.shanepark.dutypark.security.filters

import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import jakarta.servlet.Filter
import jakarta.servlet.FilterChain
import jakarta.servlet.ServletRequest
import jakarta.servlet.ServletResponse
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.Logger
import org.slf4j.LoggerFactory

class AdminAuthFilter : Filter {
    private val log: Logger = LoggerFactory.getLogger(AdminAuthFilter::class.java)

    override fun doFilter(req: ServletRequest, resp: ServletResponse, chain: FilterChain) {
        val request = req as HttpServletRequest
        val response = resp as HttpServletResponse

        request.getAttribute(LoginMember.ATTR_NAME)?.let {
            val loginMember = it as LoginMember
            if (loginMember.isAdmin) {
                return chain.doFilter(request, response)
            }
            log.info("$loginMember is not admin.")
            response.sendError(HttpServletResponse.SC_FORBIDDEN)
        }
        response.sendRedirect("/auth/login")
    }


}
