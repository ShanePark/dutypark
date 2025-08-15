package com.tistory.shanepark.dutypark.common.filter

import jakarta.servlet.Filter
import jakarta.servlet.FilterChain
import jakarta.servlet.ServletRequest
import jakarta.servlet.ServletResponse
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.stereotype.Component

@Component
class IpAccessFilter : Filter {
    override fun doFilter(request: ServletRequest?, response: ServletResponse?, chain: FilterChain) {
        val httpRequest = request as HttpServletRequest
        val httpResponse = response as HttpServletResponse
        val requestUrl = httpRequest.requestURL.toString()

        if (isValidRequest(requestUrl)) {
            chain.doFilter(request, response)
        } else {
            sendErrorResponse(httpResponse)
        }
    }

    private fun sendErrorResponse(response: HttpServletResponse) {
        response.status = HttpStatus.BAD_REQUEST.value()
        response.contentType = MediaType.APPLICATION_JSON_VALUE
        response.characterEncoding = "UTF-8"
        
        val errorMessage = """
            {
                "error": "Invalid Host",
                "message": "Direct IP access is not allowed. Please use the proper domain name.",
                "status": 400
            }
        """.trimIndent()
        
        response.writer.write(errorMessage)
        response.writer.flush()
    }

    fun isValidRequest(requestUrl: String): Boolean {
        val requestContext = requestUrl
            .replace("http://", "")
            .replace("https://", "")
            .split("/")[0]
            .split(":")[0]

        // Allow local IP for development
        if (requestContext.matches(Regex("^(?:192|172)\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\$"))) {
            return true
        }

        return !requestContext.matches(Regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}\$"))
    }

}
