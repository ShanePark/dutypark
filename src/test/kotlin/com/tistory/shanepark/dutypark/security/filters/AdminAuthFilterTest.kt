package com.tistory.shanepark.dutypark.security.filters

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

@ExtendWith(MockitoExtension::class)
class AdminAuthFilterTest {

    @Mock
    private lateinit var request: HttpServletRequest

    @Mock
    private lateinit var response: HttpServletResponse

    @Mock
    private lateinit var filterChain: FilterChain

    private lateinit var adminAuthFilter: AdminAuthFilter

    private val whiteListIp = listOf("1.2.3.4")

    @BeforeEach
    fun setup() {
        adminAuthFilter = AdminAuthFilter(whiteListIp)
    }

    @Test
    fun `should continue filter chain for local request`() {
        `when`(request.remoteAddr).thenReturn("127.0.0.1")
        `when`(request.requestURI).thenReturn("/admin")

        adminAuthFilter.doFilter(request, response, filterChain)

        verify(filterChain).doFilter(request, response)
    }

    @Test
    fun `should continue filter chain for non-admin or non-actuator request`() {
        `when`(request.requestURI).thenReturn("/nonAdminOrActuator")

        adminAuthFilter.doFilter(request, response, filterChain)

        verify(filterChain).doFilter(request, response)
    }

    @Test
    fun `should continue filter chain for admin user`() {
        `when`(request.remoteAddr).thenReturn("192.168.0.1")
        `when`(request.requestURI).thenReturn("/admin")
        val loginMember = mock(LoginMember::class.java)
        `when`(loginMember.isAdmin).thenReturn(true)
        `when`(request.getAttribute(LoginMember.attrName)).thenReturn(loginMember)

        adminAuthFilter.doFilter(request, response, filterChain)

        verify(filterChain).doFilter(request, response)
    }

    @Test
    fun `should continue filter chain for whiteListIp`() {
        `when`(request.remoteAddr).thenReturn(whiteListIp[0])
        `when`(request.requestURI).thenReturn("/actuator")
        adminAuthFilter.doFilter(request, response, filterChain)
        verify(filterChain).doFilter(request, response)
    }

    @Test
    fun `should redirect for non-admin user`() {
        `when`(request.remoteAddr).thenReturn("192.168.0.1")
        `when`(request.requestURI).thenReturn("/admin")
        val loginMember = mock(LoginMember::class.java)
        `when`(loginMember.isAdmin).thenReturn(false)
        `when`(request.getAttribute(LoginMember.attrName)).thenReturn(loginMember)

        adminAuthFilter.doFilter(request, response, filterChain)

        verify(response).sendRedirect("/login")
    }

}
