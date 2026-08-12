package com.tistory.shanepark.dutypark.member.accountdeletion

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.member.accountdeletion.dto.AccountDeletionRequest
import com.tistory.shanepark.dutypark.member.accountdeletion.repository.AccountDeletionJobRepository
import com.tistory.shanepark.dutypark.member.accountdeletion.service.AccountDeletionService
import com.tistory.shanepark.dutypark.member.domain.enums.MemberStatus
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.push.apns.domain.entity.ApnsInstallation
import com.tistory.shanepark.dutypark.push.apns.domain.repository.ApnsInstallationRepository
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.time.LocalDateTime

class AccountDeletionControllerIntegrationTest : RestDocsTest() {

    @Autowired
    lateinit var accountDeletionService: AccountDeletionService

    @Autowired
    lateinit var accountDeletionJobRepository: AccountDeletionJobRepository

    @Autowired
    lateinit var refreshTokenRepository: RefreshTokenRepository

    @Autowired
    lateinit var apnsInstallationRepository: ApnsInstallationRepository

    @Test
    fun `preview describes password and team admin transfer impact`() {
        setTeamAdmin(TestData.member.id!!)

        mockMvc.perform(
            get("/api/members/me/deletion")
                .bearer(TestData.member.id!!)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.hasPassword").value(true))
            .andExpect(jsonPath("$.socialProviders").isEmpty)
            .andExpect(jsonPath("$.teamImpact.teamId").value(TestData.team.id))
            .andExpect(jsonPath("$.teamImpact.teamName").value(TestData.team.name))
            .andExpect(jsonPath("$.teamImpact.isAdmin").value(true))
            .andExpect(jsonPath("$.teamImpact.activeMemberCount").value(2))
            .andExpect(jsonPath("$.teamImpact.willDeleteTeam").value(false))
            .andExpect(jsonPath("$.teamImpact.transferCandidates[0].memberId").value(TestData.member2.id))
            .andExpect(jsonPath("$.auxiliaryImpacts").isEmpty)
    }

    @Test
    fun `deletion rejects confirmation mismatch before reauthentication`() {
        performDeletion(AccountDeletionRequest(confirmation = "delete", password = TestData.testPass))
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("account.delete.confirmationMismatch"))

        assertThat(accountDeletionJobRepository.findByRootMemberId(TestData.member.id!!)).isNull()
        assertThat(memberRepository.findById(TestData.member.id!!).orElseThrow().status).isEqualTo(MemberStatus.ACTIVE)
    }

    @Test
    fun `preview rejects impersonated session`() {
        val impersonationToken = jwtProvider.createImpersonationToken(TestData.member, TestData.admin.id!!)

        mockMvc.perform(
            get("/api/members/me/deletion")
                .header(HttpHeaders.AUTHORIZATION, "Bearer $impersonationToken")
        )
            .andExpect(status().isForbidden)
            .andExpect(jsonPath("$.code").value("account.delete.impersonationForbidden"))
    }

    @Test
    fun `deletion rejects incorrect password without changing account state`() {
        performDeletion(AccountDeletionRequest(confirmation = "DELETE", password = "incorrect-password"))
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("account.delete.reauthenticationFailed"))

        assertThat(accountDeletionJobRepository.findByRootMemberId(TestData.member.id!!)).isNull()
        assertThat(memberRepository.findById(TestData.member.id!!).orElseThrow().status).isEqualTo(MemberStatus.ACTIVE)
    }

    @Test
    fun `successful deletion is accepted, marks pending, revokes sessions and clears cookies`() {
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        val refreshToken = refreshTokenRepository.save(
            RefreshToken(
                member = member,
                validUntil = LocalDateTime.now().plusDays(7),
                remoteAddr = "127.0.0.1",
                userAgent = "account-deletion-integration-test",
            ).apply {
                subscribePush("https://push.example.test/subscription", "p256dh", "auth")
            }
        )
        apnsInstallationRepository.save(
            ApnsInstallation(
                refreshToken = refreshToken,
                deviceToken = "account-deletion-device-token",
                sandbox = true,
            )
        )
        em.flush()

        val result = performDeletion(AccountDeletionRequest(confirmation = "DELETE", password = TestData.testPass))
            .andExpect(status().isAccepted)
            .andExpect(jsonPath("$.status").value("ACCEPTED"))
            .andExpect(jsonPath("$.jobId").isNumber)
            .andReturn()

        em.flush()
        em.clear()

        val updatedMember = memberRepository.findById(TestData.member.id!!).orElseThrow()
        assertThat(updatedMember.status).isEqualTo(MemberStatus.DELETION_PENDING)
        assertThat(updatedMember.deletionRequestedAt).isNotNull()
        assertThat(accountDeletionJobRepository.findByRootMemberId(TestData.member.id!!)).isNotNull
        assertThat(refreshTokenRepository.findAllByMemberIdIn(listOf(TestData.member.id!!))).isEmpty()
        assertThat(apnsInstallationRepository.findByDeviceToken("account-deletion-device-token")).isNull()

        val setCookies = result.response.getHeaders(HttpHeaders.SET_COOKIE)
        assertThat(setCookies).anySatisfy { cookie ->
            assertThat(cookie).contains("access_token=").contains("Max-Age=0").contains("Path=/")
        }
        assertThat(setCookies).anySatisfy { cookie ->
            assertThat(cookie).contains("refresh_token=").contains("Max-Age=0").contains("Path=/api/auth")
        }
    }

    @Test
    fun `team admin deletion requires a transfer target`() {
        setTeamAdmin(TestData.member.id!!)

        performDeletion(AccountDeletionRequest(confirmation = "DELETE", password = TestData.testPass))
            .andExpect(status().isConflict)
            .andExpect(jsonPath("$.code").value("account.delete.teamAdminTransferRequired"))

        assertThat(teamRepository.findById(TestData.team.id!!).orElseThrow().admin?.id).isEqualTo(TestData.member.id)
        assertThat(accountDeletionJobRepository.findByRootMemberId(TestData.member.id!!)).isNull()
    }

    @Test
    fun `team admin deletion rejects transfer target outside the team`() {
        setTeamAdmin(TestData.member.id!!)

        performDeletion(
            AccountDeletionRequest(
                confirmation = "DELETE",
                password = TestData.testPass,
                transferAdminToMemberId = TestData.admin.id,
            )
        )
            .andExpect(status().isConflict)
            .andExpect(jsonPath("$.code").value("account.delete.teamAdminTransferInvalid"))

        assertThat(teamRepository.findById(TestData.team.id!!).orElseThrow().admin?.id).isEqualTo(TestData.member.id)
        assertThat(accountDeletionJobRepository.findByRootMemberId(TestData.member.id!!)).isNull()
    }

    @Test
    fun `team admin deletion transfers admin to an active team member`() {
        setTeamAdmin(TestData.member.id!!)

        performDeletion(
            AccountDeletionRequest(
                confirmation = "DELETE",
                password = TestData.testPass,
                transferAdminToMemberId = TestData.member2.id,
            )
        )
            .andExpect(status().isAccepted)

        em.flush()
        em.clear()

        val updatedTeam = teamRepository.findById(TestData.team.id!!).orElseThrow()
        val job = accountDeletionJobRepository.findByRootMemberId(TestData.member.id!!)
        assertThat(updatedTeam.admin?.id).isEqualTo(TestData.member2.id)
        assertThat(job?.replacementManagerId).isEqualTo(TestData.member2.id)
        assertThat(memberRepository.findById(TestData.member.id!!).orElseThrow().status)
            .isEqualTo(MemberStatus.DELETION_PENDING)
    }

    @Test
    fun `sole team admin deletion targets the entire team without transfer`() {
        moveMemberToSoloTeam(TestData.member.id!!, TestData.team2.id!!)

        mockMvc.perform(
            get("/api/members/me/deletion")
                .bearer(TestData.member.id!!)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.teamImpact.isAdmin").value(true))
            .andExpect(jsonPath("$.teamImpact.activeMemberCount").value(1))
            .andExpect(jsonPath("$.teamImpact.willDeleteTeam").value(true))
            .andExpect(jsonPath("$.teamImpact.transferCandidates").isEmpty)

        performDeletion(AccountDeletionRequest(confirmation = "DELETE", password = TestData.testPass))
            .andExpect(status().isAccepted)

        em.flush()
        em.clear()

        val job = accountDeletionJobRepository.findByRootMemberId(TestData.member.id!!)
        assertThat(job?.deleteTeamId).isEqualTo(TestData.team2.id)
        assertThat(job?.targetTeams?.map { it.teamId }).containsExactly(TestData.team2.id)
        assertThat(memberRepository.findById(TestData.member.id!!).orElseThrow().status)
            .isEqualTo(MemberStatus.DELETION_PENDING)
    }

    @Test
    fun `duplicate service request returns the original deletion job`() {
        val login = loginMember(TestData.member)
        val request = AccountDeletionRequest(confirmation = "DELETE", password = TestData.testPass)

        val first = accountDeletionService.requestDeletion(login, request)
        val duplicate = accountDeletionService.requestDeletion(login, request)

        assertThat(duplicate.jobId).isEqualTo(first.jobId)
        assertThat(duplicate.status).isEqualTo("ACCEPTED")
        assertThat(accountDeletionJobRepository.count()).isEqualTo(1)
        assertThat(memberRepository.findById(TestData.member.id!!).orElseThrow().status)
            .isEqualTo(MemberStatus.DELETION_PENDING)
    }

    private fun performDeletion(request: AccountDeletionRequest) = mockMvc.perform(
        post("/api/members/me/deletion")
            .bearer(TestData.member.id!!)
            .contentType(MediaType.APPLICATION_JSON)
            .content(objectMapper.writeValueAsBytes(request))
    )

    private fun <T : org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder> T.bearer(
        memberId: Long,
    ): T {
        val member = memberRepository.findMemberWithTeam(memberId).orElseThrow()
        header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(member)}")
        return this
    }

    private fun setTeamAdmin(memberId: Long) {
        val team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        val member = memberRepository.findById(memberId).orElseThrow()
        team.changeAdmin(member)
        teamRepository.save(team)
        em.flush()
        em.clear()
    }

    private fun moveMemberToSoloTeam(memberId: Long, teamId: Long) {
        val member = memberRepository.findById(memberId).orElseThrow()
        val targetTeam = teamRepository.findById(teamId).orElseThrow()
        targetTeam.addMember(member)
        targetTeam.changeAdmin(member)
        memberRepository.save(member)
        teamRepository.save(targetTeam)
        em.flush()
        em.clear()
    }
}
