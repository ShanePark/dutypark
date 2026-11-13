package com.tistory.shanepark.dutypark.security.filters

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.MemberStatus
import com.tistory.shanepark.dutypark.security.service.CookieService
import jakarta.servlet.http.Cookie
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.test.context.TestPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.header
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.net.URI

/**
 * Runs through the real Spring Security chain so the origin check is exercised alongside the CORS filter.
 * Requests target the configured site host so same-origin calls look like production, where the web app
 * and the API share one origin.
 */
@AutoConfigureMockMvc
@TestPropertySource(
    properties = [
        "cookie.domain=$SITE_HOST",
        "dutypark.cors.allowed-origins=$CORS_ORIGIN",
        "dutypark.cors.allowed-origin-patterns=",
    ]
)
class OriginCheckFilterTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var mockMvc: MockMvc

    @ParameterizedTest
    @ValueSource(
        strings = [
            "https://evil.o-r.kr",
            "null",
            "http://$SITE_HOST",
            "https://$SITE_HOST.evil.o-r.kr",
        ]
    )
    fun `cross-site form post to an admin API is rejected without side effects`(origin: String) {
        val target = TestData.member

        mockMvc.perform(
            formPost("$BASE/admin/api/members/${target.id}/suspension")
                .header(HttpHeaders.ORIGIN, origin)
                .cookie(accessCookie(TestData.admin))
        )
            .andExpect(status().isForbidden)
            .andExpect(jsonPath("$.status").value(403))
            .andExpect(jsonPath("$.code").value(REJECTED_CODE))

        assertThat(statusOf(target)).isEqualTo(MemberStatus.ACTIVE)
    }

    @Test
    fun `cross-site delete to an admin API is rejected`() {
        val target = TestData.member
        target.suspend()
        memberRepository.saveAndFlush(target)

        mockMvc.perform(
            delete("$BASE/admin/api/members/${target.id}/suspension")
                .header(HttpHeaders.ORIGIN, EVIL_ORIGIN)
                .cookie(accessCookie(TestData.admin))
        )
            .andExpect(status().isForbidden)
            .andExpect(jsonPath("$.code").value(REJECTED_CODE))

        assertThat(statusOf(target)).isEqualTo(MemberStatus.SUSPENDED)
    }

    @Test
    fun `cross-site form post to a user API is rejected with the error envelope`() {
        mockMvc.perform(
            formPost("$BASE/api/auth/logout")
                .header(HttpHeaders.ORIGIN, EVIL_ORIGIN)
                .cookie(accessCookie(TestData.member))
        )
            .andExpect(status().isForbidden)
            .andExpect(jsonPath("$.status").value(403))
            .andExpect(jsonPath("$.code").value(REJECTED_CODE))
    }

    @Test
    fun `cross-site form post to a percent-encoded admin API path is rejected without side effects`() {
        val target = TestData.member

        // URI.create keeps %61 ("a") raw; Spring MVC decodes it and routes to /admin/api/... anyway.
        mockMvc.perform(
            post(URI.create("$BASE/%61dmin/api/members/${target.id}/suspension"))
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .header(HttpHeaders.ORIGIN, EVIL_ORIGIN)
                .cookie(accessCookie(TestData.admin))
        )
            .andExpect(status().isForbidden)
            .andExpect(jsonPath("$.status").value(403))
            .andExpect(jsonPath("$.code").value(REJECTED_CODE))

        assertThat(statusOf(target)).isEqualTo(MemberStatus.ACTIVE)
    }

    @Test
    fun `same-origin post from the configured site origin passes`() {
        val target = TestData.member

        mockMvc.perform(
            formPost("$BASE/admin/api/members/${target.id}/suspension")
                .header(HttpHeaders.ORIGIN, SITE)
                .cookie(accessCookie(TestData.admin))
        )
            .andExpect(status().isOk)
        assertThat(statusOf(target)).isEqualTo(MemberStatus.SUSPENDED)

        mockMvc.perform(
            post("$BASE/api/auth/logout")
                .header(HttpHeaders.ORIGIN, SITE)
                .cookie(accessCookie(TestData.member2))
        )
            .andExpect(status().isNoContent)
    }

    @Test
    fun `post from a CORS allowlisted origin passes`() {
        val target = TestData.member

        mockMvc.perform(
            post("$BASE/admin/api/members/${target.id}/suspension")
                .header(HttpHeaders.ORIGIN, CORS_ORIGIN)
                .cookie(accessCookie(TestData.admin))
        )
            .andExpect(status().isOk)
        assertThat(statusOf(target)).isEqualTo(MemberStatus.SUSPENDED)

        mockMvc.perform(
            post("$BASE/api/auth/logout")
                .header(HttpHeaders.ORIGIN, CORS_ORIGIN)
                .cookie(accessCookie(TestData.member2))
        )
            .andExpect(status().isNoContent)
            .andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, CORS_ORIGIN))
    }

    @Test
    fun `post without an Origin header passes like native clients`() {
        val target = TestData.member

        mockMvc.perform(
            post("$BASE/admin/api/members/${target.id}/suspension")
                .cookie(accessCookie(TestData.admin))
        )
            .andExpect(status().isOk)
        assertThat(statusOf(target)).isEqualTo(MemberStatus.SUSPENDED)

        mockMvc.perform(
            post("$BASE/api/auth/logout")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.member2)}")
        )
            .andExpect(status().isNoContent)
    }

    @Test
    fun `read-only request with a cross-site Origin is not subject to the origin check`() {
        mockMvc.perform(
            get("$BASE/admin/api/members/${TestData.member.id}")
                .header(HttpHeaders.ORIGIN, EVIL_ORIGIN)
                .cookie(accessCookie(TestData.admin))
        )
            .andExpect(status().isOk)
    }

    @Test
    fun `CORS preflight from an allowlisted origin is unaffected`() {
        mockMvc.perform(
            options("$BASE/api/auth/logout")
                .header(HttpHeaders.ORIGIN, CORS_ORIGIN)
                .header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, "POST")
        )
            .andExpect(status().isOk)
            .andExpect(header().string(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN, CORS_ORIGIN))
    }

    private fun formPost(url: String): MockHttpServletRequestBuilder =
        post(url).contentType(MediaType.APPLICATION_FORM_URLENCODED)

    private fun accessCookie(member: Member) = Cookie(CookieService.ACCESS_TOKEN_COOKIE, getJwt(member))

    private fun statusOf(member: Member): MemberStatus {
        em.flush()
        em.clear()
        return memberRepository.findById(member.id!!).orElseThrow().status
    }

    companion object {
        private const val SITE = "https://$SITE_HOST"

        // MockMvc keeps port 80 unless the URL names one, which would make same-origin calls look cross-origin.
        private const val BASE = "$SITE:443"
        private const val EVIL_ORIGIN = "https://evil.o-r.kr"
        private const val REJECTED_CODE = "common.badRequest"
    }
}

private const val SITE_HOST = "dutypark.example.com"
private const val CORS_ORIGIN = "https://app.example.com"
