package com.tistory.shanepark.dutypark.common.filter

import org.springframework.stereotype.Component
import javax.servlet.Filter
import javax.servlet.FilterChain
import javax.servlet.ServletRequest
import javax.servlet.ServletResponse
import javax.servlet.http.HttpServletRequest

@Component
class IpAccessFilter : Filter {
    override fun doFilter(request: ServletRequest?, response: ServletResponse?, chain: FilterChain) {
        val requestUrl = (request as HttpServletRequest).requestURL.toString()

        if (isNotIpPattern(requestUrl)) {
            chain.doFilter(request, response)
        }

    }

    fun isNotIpPattern(requestUrl: String): Boolean {
        val requestContext = requestUrl
            .replace("http://", "")
            .replace("https://", "")
            .split("/")[0]
            .split(":")[0]
        return !requestContext.matches(Regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\$"))
    }

}
