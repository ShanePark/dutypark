package com.tistory.shanepark.dutypark.common.logging

import ch.qos.logback.classic.Level
import ch.qos.logback.classic.Logger
import ch.qos.logback.core.read.ListAppender
import ch.qos.logback.classic.spi.ILoggingEvent
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource
import org.slf4j.LoggerFactory
import org.slf4j.MDC
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.mock.web.MockHttpServletResponse
import org.springframework.web.servlet.HandlerMapping
import java.util.UUID

class RequestLoggingFilterTest {
    private fun capture(level: Level = Level.DEBUG, action: () -> Unit): List<ILoggingEvent> {
        val logger = LoggerFactory.getLogger(RequestLoggingFilter::class.java) as Logger
        val previousLevel = logger.level
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.level = level
        logger.addAppender(appender)
        return try { action(); appender.list.toList() } finally {
            logger.detachAppender(appender)
            logger.level = previousLevel
            appender.stop()
        }
    }

    @Test
    fun `mutation outcome uses generated correlation safe route and actor then restores MDC`() {
        val request = MockHttpServletRequest("POST", "/members/secret-uri")
        request.addHeader("X-Request-ID", "untrusted-request-id")
        request.queryString = "token=secret-query"
        val response = MockHttpServletResponse()
        MDC.put("requestId", "previous-request")
        try {
            val events = capture {
                RequestLoggingFilter().doFilter(request, response) { _, _ ->
                    request.setAttribute(HandlerMapping.BEST_MATCHING_PATTERN_ATTRIBUTE, "/members/{id}")
                    request.setAttribute(LoginMember.ATTR_NAME, LoginMember(id = 7, name = "member", isImpersonating = true, originalMemberId = 2))
                    response.status = 201
                    assertThat(MDC.get("requestId")).isEqualTo(response.getHeader("X-Request-ID"))
                }
            }
            UUID.fromString(response.getHeader("X-Request-ID"))
            assertThat(events).hasSize(1)
            assertThat(events.single().level).isEqualTo(Level.DEBUG)
            assertThat(events.single().formattedMessage).contains("/members/{id}", "201", "originalMemberId", "durationMs")
                .doesNotContain("secret-uri", "secret-query", "untrusted-request-id")
            assertThat(MDC.get("requestId")).isEqualTo("previous-request")
        } finally { MDC.remove("requestId") }
    }

    @ParameterizedTest
    @ValueSource(strings = ["POST", "PUT", "PATCH", "DELETE"])
    fun `successful mutation only logs at debug level`(method: String) {
        val events = capture {
            RequestLoggingFilter().doFilter(MockHttpServletRequest(method, "/private"), MockHttpServletResponse()) { _, _ -> }
        }
        assertThat(events).hasSize(1)
        assertThat(events.single().level).isEqualTo(Level.DEBUG)

        val infoEvents = capture(Level.INFO) {
            RequestLoggingFilter().doFilter(MockHttpServletRequest(method, "/private"), MockHttpServletResponse()) { _, _ -> }
        }
        assertThat(infoEvents).isEmpty()
    }

    @ParameterizedTest
    @ValueSource(ints = [500, 503])
    fun `server error response logs at error level`(status: Int) {
        val events = capture {
            RequestLoggingFilter().doFilter(MockHttpServletRequest("GET", "/private"), MockHttpServletResponse()) { _, resp ->
                (resp as MockHttpServletResponse).status = status
            }
        }
        assertThat(events).hasSize(1)
        assertThat(events.single().level).isEqualTo(Level.ERROR)
    }

    @Test
    fun `ordinary not found response stays at debug level`() {
        val events = capture {
            RequestLoggingFilter().doFilter(MockHttpServletRequest("GET", "/private"), MockHttpServletResponse()) { _, resp ->
                (resp as MockHttpServletResponse).status = 404
            }
        }
        assertThat(events).hasSize(1)
        assertThat(events.single().level).isEqualTo(Level.DEBUG)
    }

    @Test
    fun `read success is quiet and rejected request logs normalized code without raw path`() {
        val response = MockHttpServletResponse()
        val events = capture {
            RequestLoggingFilter().doFilter(MockHttpServletRequest("GET", "/secret"), response) { _, _ -> }
            RequestLoggingFilter().doFilter(MockHttpServletRequest("GET", "/private"), MockHttpServletResponse()) { req, resp ->
                req.setAttribute("dutypark.logging.errorCode", "auth.required")
                (resp as MockHttpServletResponse).status = 401
            }
        }
        assertThat(events).hasSize(1)
        assertThat(events.single().formattedMessage).contains("auth.required", "<unmatched>").doesNotContain("/private", "/secret")
        assertThat(events.single().level.toString()).isEqualTo("WARN")
        assertThat(MDC.get("requestId")).isNull()
    }

    @Test
    fun `unhandled failure outcome reports 500 and preserves original throwable`() {
        val failure = IllegalStateException("secret-error")
        val events = capture {
            val caught = assertThrows<IllegalStateException> {
                RequestLoggingFilter().doFilter(MockHttpServletRequest("POST", "/private"), MockHttpServletResponse()) { _, _ -> throw failure }
            }
            assertThat(caught).isSameAs(failure)
        }
        assertThat(events).hasSize(1)
        assertThat(events.single().level).isEqualTo(Level.ERROR)
        assertThat(events.single().formattedMessage).contains("500", "IllegalStateException").doesNotContain("secret-error", "/private")
        assertThat(MDC.get("requestId")).isNull()
    }
}
