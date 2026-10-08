package com.tistory.shanepark.dutypark.common.logging

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.MDC
import org.springframework.core.Ordered
import org.springframework.core.annotation.Order
import org.springframework.stereotype.Component
import org.springframework.web.filter.OncePerRequestFilter
import org.springframework.web.servlet.HandlerMapping
import java.util.UUID

@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 10)
class RequestLoggingFilter : OncePerRequestFilter() {
    private val log = logger()

    override fun doFilterInternal(request: HttpServletRequest, response: HttpServletResponse, filterChain: FilterChain) {
        val previousRequestId = MDC.get("requestId")
        val requestId = UUID.randomUUID().toString()
        val startedAt = System.nanoTime()
        var failure: Throwable? = null
        MDC.put("requestId", requestId)
        request.setAttribute("dutypark.logging.requestId", requestId)
        response.setHeader("X-Request-ID", requestId)
        try {
            filterChain.doFilter(request, response)
        } catch (error: Throwable) {
            failure = error
            throw error
        } finally {
            try {
                val status = if (failure != null) 500 else response.status
                if (status >= 400 || request.method in MUTATION_METHODS) {
                    val context = auditContext(
                        linkedMapOf(
                            "event" to "http_request_completed",
                            "method" to request.method,
                            // URI and query parameters may contain credentials. Only the matched route is safe.
                            "pathPattern" to (request.getAttribute(HandlerMapping.BEST_MATCHING_PATTERN_ATTRIBUTE) as? String ?: "<unmatched>"),
                            "status" to status,
                            "durationMs" to (System.nanoTime() - startedAt) / 1_000_000,
                            "actor" to (request.getAttribute(LoginMember.ATTR_NAME) as? LoginMember)?.toAuditActor(),
                            "errorCode" to request.getAttribute("dutypark.logging.errorCode"),
                            "exceptionType" to (failure?.javaClass?.name ?: request.getAttribute("dutypark.logging.exceptionType")),
                        )
                    )
                    when {
                        status >= 500 -> log.error("{}", context)
                        status == 404 -> log.debug("{}", context)
                        status >= 400 -> log.warn("{}", context)
                        request.method in MUTATION_METHODS -> log.debug("{}", context)
                    }
                }
            } finally {
                if (previousRequestId == null) MDC.remove("requestId") else MDC.put("requestId", previousRequestId)
            }
        }
    }

    companion object {
        private val MUTATION_METHODS = setOf("POST", "PUT", "PATCH", "DELETE")
    }
}
