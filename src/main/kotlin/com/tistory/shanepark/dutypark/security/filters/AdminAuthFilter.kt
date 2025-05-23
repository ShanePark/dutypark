package com.tistory.shanepark.dutypark.security.filters

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import jakarta.servlet.Filter
import jakarta.servlet.FilterChain
import jakarta.servlet.ServletRequest
import jakarta.servlet.ServletResponse
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse

class AdminAuthFilter : Filter {
    private val log = logger()

    override fun doFilter(req: ServletRequest, resp: ServletResponse, chain: FilterChain) {
        val request = req as HttpServletRequest
        val response = resp as HttpServletResponse

        request.getAttribute(LoginMember.ATTR_NAME)?.let {
            val loginMember = it as LoginMember
            if (loginMember.isAdmin) {
                return chain.doFilter(request, response)
            }
            log.info("$loginMember is not admin.")
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED)
        }
        log.info("LoginMember null try to access admin page. ip: ${request.remoteAddr}")
    }


}
