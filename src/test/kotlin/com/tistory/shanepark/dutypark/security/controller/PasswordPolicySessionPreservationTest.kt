package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.*

@AutoConfigureMockMvc
class PasswordPolicySessionPreservationTest : DutyparkIntegrationTest() {
    @Autowired lateinit var mockMvc: MockMvc

    @ParameterizedTest(name = "administrator impersonation={0}")
    @ValueSource(booleans = [false, true])
    fun `impersonation cannot change a password even with valid credentials or admin privileges`(administrator: Boolean) {
        val impersonated = if (administrator) TestData.admin else TestData.member
        val passwordOwner = memberRepository.findById(TestData.member.id!!).orElseThrow()
        val passwordBefore = passwordOwner.password
        val ownerSession = sessionTokenService.createRefreshToken(passwordOwner.id!!, "127.0.0.1", "password-owner")
        val jwt = getImpersonationJwt(impersonated, TestData.member2)

        mockMvc.perform(put("/api/auth/password")
            .header(HttpHeaders.AUTHORIZATION, "Bearer $jwt")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""{"memberId":${passwordOwner.id},"currentPassword":"${TestData.testPass}","newPassword":"new-password"}"""))
            .andExpect(status().isForbidden)
            .andExpect(jsonPath("$.code").value("auth.reauth.impersonationForbidden"))

        em.flush()
        em.clear()
        assertThat(memberRepository.findById(passwordOwner.id!!).orElseThrow().password).isEqualTo(passwordBefore)
        assertThat(sessionTokenService.isSessionActive(ownerSession.id!!, passwordOwner.id!!)).isTrue()
        mockMvc.perform(get("/api/auth/status").header(HttpHeaders.AUTHORIZATION, "Bearer $jwt"))
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.id").value(impersonated.id))
            .andExpect(jsonPath("$.isImpersonating").value(true))
    }
}
