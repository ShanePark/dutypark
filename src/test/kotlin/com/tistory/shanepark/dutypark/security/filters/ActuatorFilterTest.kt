package com.tistory.shanepark.dutypark.security.filters

import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import org.mockito.junit.jupiter.MockitoExtension

@ExtendWith(MockitoExtension::class)
class ActuatorFilterTest {

    @Mock
    private lateinit var request: HttpServletRequest

    @Mock
    private lateinit var response: HttpServletResponse

    @Mock
    private lateinit var filterChain: FilterChain

    private lateinit var actuatorFilter: ActuatorFilter

    private val whiteIpList = listOf("1,2,3,4")

    @BeforeEach
    fun setup() {
        actuatorFilter = ActuatorFilter(whiteIpList)
    }

    @Test
    fun `should continue filter chain for local request`() {
        `when`(request.remoteAddr).thenReturn("127.0.0.1")

        actuatorFilter.doFilter(request, response, filterChain)

        verify(filterChain).doFilter(request, response)
    }

    @Test
    fun `should continue filter chain for white list ip request`() {
        `when`(request.remoteAddr).thenReturn(whiteIpList[0])

        actuatorFilter.doFilter(request, response, filterChain)

        verify(filterChain).doFilter(request, response)
    }

    @Test
    fun `should send error for non-local and non-white list ip request`() {
        `when`(request.remoteAddr).thenReturn("invalid ip")

        actuatorFilter.doFilter(request, response, filterChain)
        verify(response).sendError(HttpServletResponse.SC_FORBIDDEN, "You are not allowed to access this resource.")

    }

}
