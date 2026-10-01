package com.tistory.shanepark.dutypark.security.filters

import ch.qos.logback.classic.Logger
import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.core.read.ListAppender
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.Mockito.*
import org.mockito.junit.jupiter.MockitoExtension
import org.assertj.core.api.Assertions.assertThat
import org.slf4j.LoggerFactory

@ExtendWith(MockitoExtension::class)
class AdminAuthFilterTest {

    @Mock
    private lateinit var request: HttpServletRequest

    @Mock
    private lateinit var response: HttpServletResponse

    @Mock
    private lateinit var filterChain: FilterChain

    private lateinit var adminAuthFilter: AdminAuthFilter

    @BeforeEach
    fun setup() {
        adminAuthFilter = AdminAuthFilter()
    }

    @Test
    fun `should continue filter chain for admin user`() {
        val loginMember = mock(LoginMember::class.java)
        `when`(loginMember.isAdmin).thenReturn(true)
        `when`(request.getAttribute(LoginMember.ATTR_NAME)).thenReturn(loginMember)

        adminAuthFilter.doFilter(request, response, filterChain)

        verify(filterChain).doFilter(request, response)
        verify(response, never()).sendError(anyInt())
    }

    @Test
    fun `should 401 error for non-admin user`() {
        val loginMember = mock(LoginMember::class.java)
        `when`(loginMember.id).thenReturn(42L)
        `when`(loginMember.name).thenReturn("Ordinary Member")
        `when`(loginMember.isAdmin).thenReturn(false)
        `when`(request.getAttribute(LoginMember.ATTR_NAME)).thenReturn(loginMember)
        `when`(request.method).thenReturn("DELETE")
        `when`(request.requestURI).thenReturn("/api/admin/members/73")

        val logs = captureAdminAuthLogs {
            adminAuthFilter.doFilter(request, response, filterChain)
        }

        verify(response).sendError(HttpServletResponse.SC_UNAUTHORIZED)
        verify(filterChain, never()).doFilter(any(), any())
        assertThat(logs)
            .contains("Ordinary Member", "42", "/api/admin/members/73", "DELETE", "401", "not_admin")
            .doesNotContain("private@example.com")
    }

    @Test
    fun `should 401 error when access token is missing`() {
        `when`(request.getAttribute(LoginMember.ATTR_NAME)).thenReturn(null)
        `when`(request.method).thenReturn("GET")
        `when`(request.requestURI).thenReturn("/api/admin/members")

        val logs = captureAdminAuthLogs {
            adminAuthFilter.doFilter(request, response, filterChain)
        }

        verify(response).sendError(HttpServletResponse.SC_UNAUTHORIZED)
        verify(filterChain, never()).doFilter(any(), any())
        assertThat(logs).contains("/api/admin/members", "GET", "401", "missing_login_member")
    }

    private fun captureAdminAuthLogs(block: () -> Unit): String {
        val logger = LoggerFactory.getLogger(AdminAuthFilter::class.java) as Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try {
            block()
        } finally {
            logger.detachAppender(appender)
            appender.stop()
        }
        return appender.list.joinToString("\n") { it.formattedMessage }
    }

}
