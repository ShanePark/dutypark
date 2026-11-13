package com.tistory.shanepark.dutypark.security.filters

import com.tistory.shanepark.dutypark.common.config.logger
import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.web.cors.CorsConfiguration
import org.springframework.web.filter.OncePerRequestFilter

/**
 * Blocks cross-site state-changing API requests (CSRF) that carry the browser's auth cookies.
 *
 * SameSite=Lax is not enough here: the production host is a subdomain of a shared domain that is not on the
 * Public Suffix List, so sibling subdomains are same-site and their form posts carry the cookies.
 * Browsers always send Origin on cross-origin writes, so a write is accepted only from an allowed origin or
 * without Origin at all (native iOS URLSession, server-to-server). `Origin: null` (sandboxed frames,
 * privacy redirects) is rejected because no legitimate flow posts to these APIs with it.
 */
class OriginCheckFilter(
    private val allowedOrigins: CorsConfiguration,
) : OncePerRequestFilter() {

    private val log = logger()

    override fun shouldNotFilter(request: HttpServletRequest): Boolean {
        if (request.method !in STATE_CHANGING_METHODS) return true
        val path = request.requestURI.removePrefix(request.contextPath)
        return PROTECTED_PATH_PREFIXES.none(path::startsWith)
    }

    override fun doFilterInternal(request: HttpServletRequest, response: HttpServletResponse, chain: FilterChain) {
        val origin = request.getHeader(HttpHeaders.ORIGIN)
        if (origin == null || isAllowed(origin)) {
            chain.doFilter(request, response)
            return
        }

        log.warn("Rejected cross-site {} {} from origin {}", request.method, request.requestURI, origin)
        request.setAttribute("dutypark.logging.errorCode", REJECTED_CODE)
        response.status = HttpServletResponse.SC_FORBIDDEN
        response.contentType = MediaType.APPLICATION_JSON_VALUE
        response.characterEncoding = Charsets.UTF_8.name()
        response.writer.write("""{"status":403,"code":"$REJECTED_CODE"}""")
    }

    private fun isAllowed(origin: String): Boolean =
        origin != "null" && allowedOrigins.checkOrigin(origin) != null

    companion object {
        private val STATE_CHANGING_METHODS = setOf("POST", "PUT", "PATCH", "DELETE")
        private val PROTECTED_PATH_PREFIXES = listOf("/api/", "/admin/api/")
        private const val REJECTED_CODE = "common.badRequest"
    }
}
