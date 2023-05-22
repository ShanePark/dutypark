package com.tistory.shanepark.dutypark.security.filters

import jakarta.servlet.Filter
import jakarta.servlet.FilterChain
import jakarta.servlet.ServletRequest
import jakarta.servlet.ServletResponse
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.Logger
import org.slf4j.LoggerFactory

class ActuatorFilter(
    private val whiteIpList: List<String>
) : Filter {
    private val log: Logger = LoggerFactory.getLogger(ActuatorFilter::class.java)

    override fun doFilter(req: ServletRequest, resp: ServletResponse, chain: FilterChain) {
        val remoteAddr = req.remoteAddr

        if (isLocalRequest(remoteAddr) || whiteIpList.contains(remoteAddr)) {
            return chain.doFilter(req, resp)
        }

        log.info("Forbidden actuator access from $remoteAddr")

        val response = resp as HttpServletResponse
        response.sendError(HttpServletResponse.SC_FORBIDDEN, "You are not allowed to access this resource.")
    }

    private fun isLocalRequest(remoteAddr: String): Boolean {
        return remoteAddr == "0:0:0:0:0:0:0:1" || remoteAddr == "127.0.0.1"
    }

}
