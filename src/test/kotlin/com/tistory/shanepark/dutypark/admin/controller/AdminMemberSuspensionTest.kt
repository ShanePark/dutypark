package com.tistory.shanepark.dutypark.admin.controller

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.member.domain.enums.MemberStatus
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.repository.LoginAttemptRepository
import jakarta.servlet.http.Cookie
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.time.Instant

@AutoConfigureMockMvc
class AdminMemberSuspensionTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var refreshTokenService: RefreshTokenService

    @Autowired
    lateinit var loginAttemptRepository: LoginAttemptRepository

    @BeforeEach
    fun cleanup() {
        loginAttemptRepository.deleteAll()
    }

    @Test
    fun `non-admin cannot suspend a member`() {
        mockMvc.perform(
            post("/admin/api/members/{memberId}/suspension", TestData.member.id!!)
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.member2)}")
        )
            .andExpect(status().isUnauthorized)

        assertThat(reloadMember().status).isEqualTo(MemberStatus.ACTIVE)
    }

    @Test
    fun `admin suspends a member and every session is revoked`() {
        refreshTokenService.createRefreshToken(TestData.member.id!!, "127.0.0.1", "integration-test")
        refreshTokenService.createRefreshToken(TestData.member.id!!, "127.0.0.2", "integration-test")
        em.flush()
        em.clear()

        suspend(TestData.member.id!!).andExpect(status().isOk)
        em.flush()
        em.clear()

        assertThat(reloadMember().status).isEqualTo(MemberStatus.SUSPENDED)
        assertThat(refreshTokenService.findRefreshTokens(TestData.member.id!!, validOnly = false)).isEmpty()
    }

    @Test
    fun `suspended member cannot log in with password`() {
        suspend(TestData.member.id!!).andExpect(status().isOk)
        em.flush()
        em.clear()

        mockMvc.perform(
            post("/api/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(LoginDto(TestData.member.email, TestData.testPass, false)))
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("auth.account.suspended"))
    }

    @Test
    fun `suspended member with a wrong password still gets the generic login failure`() {
        suspend(TestData.member.id!!).andExpect(status().isOk)
        em.flush()
        em.clear()

        mockMvc.perform(
            post("/api/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(LoginDto(TestData.member.email, "wrongPass", false)))
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("auth.login.failed"))
    }

    @Test
    fun `suspended member cannot refresh an existing session`() {
        val refreshToken = refreshTokenService.createRefreshToken(
            memberId = TestData.member.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "integration-test",
        )
        val tokenValue = refreshToken.token
        em.flush()
        em.clear()

        suspend(TestData.member.id!!).andExpect(status().isOk)
        em.flush()
        em.clear()

        mockMvc.perform(
            post("/api/auth/refresh").cookie(Cookie("refresh_token", tokenValue))
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("auth.refresh.invalid"))
    }

    @Test
    fun `suspended member cannot be impersonated`() {
        makeManagerRelation(manager = TestData.member2, managed = TestData.member)
        val managerJwt = getJwt(TestData.member2)
        em.flush()
        em.clear()

        suspend(TestData.member.id!!).andExpect(status().isOk)
        em.flush()
        em.clear()

        mockMvc.perform(
            post("/api/auth/impersonate/{targetMemberId}", TestData.member.id!!)
                .header(HttpHeaders.AUTHORIZATION, "Bearer $managerJwt")
        )
            .andExpect(status().isForbidden)
            .andExpect(jsonPath("$.code").value("auth.account.suspended"))
    }

    @Test
    fun `suspending an already suspended member is idempotent`() {
        suspend(TestData.member.id!!).andExpect(status().isOk)
        em.flush()
        em.clear()

        suspend(TestData.member.id!!).andExpect(status().isOk)
        em.flush()
        em.clear()

        assertThat(reloadMember().status).isEqualTo(MemberStatus.SUSPENDED)
    }

    @Test
    fun `suspending a deletion pending member conflicts`() {
        TestData.member.markDeletionPending(Instant.now())
        memberRepository.save(TestData.member)
        em.flush()
        em.clear()

        suspend(TestData.member.id!!)
            .andExpect(status().isConflict)
            .andExpect(jsonPath("$.code").value("member.suspend.deletionPending"))

        assertThat(reloadMember().status).isEqualTo(MemberStatus.DELETION_PENDING)
    }

    @Test
    fun `admin reinstates a suspended member and login works again`() {
        suspend(TestData.member.id!!).andExpect(status().isOk)
        em.flush()
        em.clear()

        reinstate(TestData.member.id!!).andExpect(status().isOk)
        em.flush()
        em.clear()

        assertThat(reloadMember().status).isEqualTo(MemberStatus.ACTIVE)

        mockMvc.perform(
            post("/api/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(LoginDto(TestData.member.email, TestData.testPass, false)))
        )
            .andExpect(status().isOk)
    }

    @Test
    fun `reinstating a member that is not suspended is idempotent`() {
        reinstate(TestData.member.id!!).andExpect(status().isOk)
        em.flush()
        em.clear()

        assertThat(reloadMember().status).isEqualTo(MemberStatus.ACTIVE)
    }

    @Test
    fun `admin member list and detail expose the member status`() {
        suspend(TestData.member.id!!).andExpect(status().isOk)
        em.flush()
        em.clear()

        mockMvc.perform(
            org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                .get("/admin/api/members")
                .param("keyword", TestData.member.name)
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.admin)}")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.content[0].status").value("SUSPENDED"))

        mockMvc.perform(
            org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                .get("/admin/api/members/{memberId}", TestData.member.id!!)
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.admin)}")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.status").value("SUSPENDED"))
    }

    private fun suspend(memberId: Long) = mockMvc.perform(
        post("/admin/api/members/{memberId}/suspension", memberId)
            .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.admin)}")
    )

    private fun reinstate(memberId: Long) = mockMvc.perform(
        delete("/admin/api/members/{memberId}/suspension", memberId)
            .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.admin)}")
    )

    private fun reloadMember() = memberRepository.findById(TestData.member.id!!).orElseThrow()

}
