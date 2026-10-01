package com.tistory.shanepark.dutypark.security.filters

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.logging.auditContext
import com.tistory.shanepark.dutypark.common.logging.toAuditActor
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

        val loginMember = request.getAttribute(LoginMember.ATTR_NAME) as? LoginMember
        if (loginMember == null) {
            log.warn(
                "Admin access denied {}",
                auditContext(
                    linkedMapOf(
                        "event" to "admin.access.denied",
                        "actor" to null,
                        "request" to mapOf("method" to request.method, "path" to request.requestURI),
                        "status" to HttpServletResponse.SC_UNAUTHORIZED,
                        "reason" to "missing_login_member",
                        "ipAddress" to request.remoteAddr,
                    )
                ),
            )
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED)
            return
        }

        if (!loginMember.isAdmin) {
            log.warn(
                "Admin access denied {}",
                auditContext(
                    linkedMapOf(
                        "event" to "admin.access.denied",
                        "actor" to loginMember.toAuditActor(),
                        "request" to mapOf("method" to request.method, "path" to request.requestURI),
                        "status" to HttpServletResponse.SC_UNAUTHORIZED,
                        "reason" to "not_admin",
                    )
                ),
            )
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED)
            return
        }

        chain.doFilter(request, response)
    }
}
