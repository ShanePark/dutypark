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

class AdminAuthFilter(
    private val whiteIpList: List<String>
) : Filter {
    private val log: Logger = LoggerFactory.getLogger(AdminAuthFilter::class.java)

    override fun doFilter(req: ServletRequest, resp: ServletResponse, chain: FilterChain) {
        val request = req as HttpServletRequest
        val response = resp as HttpServletResponse

        if (shouldSkipFilter(request)) {
            return chain.doFilter(request, response)
        }

        request.getAttribute(LoginMember.attrName)?.let {
            val loginMember = it as LoginMember
            if (loginMember.isAdmin) {
                return chain.doFilter(request, response)
            }
            log.info("$loginMember is not admin.")
            response.sendError(HttpServletResponse.SC_FORBIDDEN)
        }
        response.sendRedirect("/login")
    }

    private fun shouldSkipFilter(request: HttpServletRequest): Boolean {
        val adminRequest = request.requestURI.startsWith("/admin")
        val actuatorRequest = request.requestURI.startsWith("/actuator")

        if (!adminRequest && !actuatorRequest)
            return true

        if (isLocalRequest(request))
            return true

        return request.remoteAddr in whiteIpList
    }

    private fun isLocalRequest(request: HttpServletRequest): Boolean {
        val remoteAddr = request.remoteAddr
        return remoteAddr == "0:0:0:0:0:0:0:1" || remoteAddr == "127.0.0.1"
    }

}
