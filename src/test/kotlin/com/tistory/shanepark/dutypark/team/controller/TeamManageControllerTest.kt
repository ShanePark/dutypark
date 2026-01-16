package com.tistory.shanepark.dutypark.team.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTemplate
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.team.domain.enums.WorkType
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.http.MediaType
import org.springframework.http.HttpHeaders
import org.springframework.mock.web.MockMultipartFile
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

class TeamManageControllerTest : RestDocsTest() {

    @Test
    fun `manager can load team details`() {
        setTeamAdmin(TestData.member.id!!)

        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/teams/manage/{teamId}", TestData.team.id!!)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.id").value(TestData.team.id))
            .andExpect(jsonPath("$.name").value(TestData.team.name))
    }

    @Test
    fun `non-manager cannot load team details`() {
        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/teams/manage/{teamId}", TestData.team.id!!)
                .withAuth(TestData.member2)
        )
            .andExpect(status().isUnauthorized)
    }

    @Test
    fun `manager can change team admin`() {
        setTeamAdmin(TestData.member.id!!)

        mockMvc.perform(
            MockMvcRequestBuilders.put("/api/teams/manage/{teamId}/admin", TestData.team.id!!)
                .param("memberId", TestData.member2.id!!.toString())
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)

        val updated = teamRepository.findById(TestData.team.id!!).orElseThrow()
        assertThat(updated.admin?.id).isEqualTo(TestData.member2.id)
    }

    @Test
    fun `manager can update batch template`() {
        setTeamAdmin(TestData.member.id!!)

        mockMvc.perform(
            MockMvcRequestBuilders.patch("/api/teams/manage/{teamId}/batch-template", TestData.team.id!!)
                .param("templateName", DutyBatchTemplate.SUNGSIM_CAKE.name)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)

        val updated = teamRepository.findById(TestData.team.id!!).orElseThrow()
        assertThat(updated.dutyBatchTemplate).isEqualTo(DutyBatchTemplate.SUNGSIM_CAKE)
    }

    @Test
    fun `manager can update work type`() {
        setTeamAdmin(TestData.member.id!!)

        mockMvc.perform(
            MockMvcRequestBuilders.patch("/api/teams/manage/{teamId}/work-type", TestData.team.id!!)
                .param("workType", WorkType.FLEXIBLE.name)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)

        val updated = teamRepository.findById(TestData.team.id!!).orElseThrow()
        assertThat(updated.workType).isEqualTo(WorkType.FLEXIBLE)
    }

    @Test
    fun `batch upload requires template`() {
        setTeamAdmin(TestData.member.id!!)
        val team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        team.dutyBatchTemplate = null
        teamRepository.save(team)

        val file = MockMultipartFile(
            "file",
            "duty.xlsx",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "dummy".toByteArray()
        )

        mockMvc.perform(
            MockMvcRequestBuilders.multipart("/api/teams/manage/{teamId}/duty", TestData.team.id!!)
                .file(file)
                .param("year", "2024")
                .param("month", "1")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.member)}")
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.error").value("templateName is required"))
    }

    @Test
    fun `manager can update default duty`() {
        setTeamAdmin(TestData.member.id!!)

        mockMvc.perform(
            MockMvcRequestBuilders.patch("/api/teams/manage/{teamId}/default-duty", TestData.team.id!!)
                .param("color", "#123456")
                .param("name", "DEFAULT")
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)

        val updated = teamRepository.findById(TestData.team.id!!).orElseThrow()
        assertThat(updated.defaultDutyName).isEqualTo("DEFAULT")
        assertThat(updated.defaultDutyColor).isEqualTo("#123456")
    }

    @Test
    fun `manager can add member to team`() {
        setTeamAdmin(TestData.member.id!!)
        val newMember = memberRepository.save(Member("joiner", "joiner@duty.park", "pass"))

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/teams/manage/{teamId}/members", TestData.team.id!!)
                .param("memberId", newMember.id!!.toString())
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)

        val updatedMember = memberRepository.findById(newMember.id!!).orElseThrow()
        assertThat(updatedMember.team?.id).isEqualTo(TestData.team.id)
    }

    @Test
    fun `manager can remove member from team`() {
        setTeamAdmin(TestData.member.id!!)
        val member = memberRepository.save(Member("removee", "removee@duty.park", "pass"))
        val team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        team.addMember(member)
        teamRepository.save(team)

        mockMvc.perform(
            MockMvcRequestBuilders.delete("/api/teams/manage/{teamId}/members", TestData.team.id!!)
                .param("memberId", member.id!!.toString())
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)

        val updatedMember = memberRepository.findById(member.id!!).orElseThrow()
        assertThat(updatedMember.team).isNull()
    }

    @Test
    fun `members endpoint returns candidates without team`() {
        val member = memberRepository.save(Member("candidate", "candidate@duty.park", "pass"))

        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/teams/manage/members")
                .param("keyword", "candidate")
                .param("page", "0")
                .param("size", "10")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.content.length()").value(1))
            .andExpect(jsonPath("$.content[0].id").value(member.id))
    }

    @Test
    fun `team admin can add and remove manager`() {
        setTeamAdmin(TestData.member.id!!)

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/teams/manage/{teamId}/manager", TestData.team.id!!)
                .param("memberId", TestData.member2.id!!.toString())
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)

        var team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        assertThat(team.isManager(TestData.member2.id)).isTrue

        mockMvc.perform(
            MockMvcRequestBuilders.delete("/api/teams/manage/{teamId}/manager", TestData.team.id!!)
                .param("memberId", TestData.member2.id!!.toString())
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)

        team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        assertThat(team.isManager(TestData.member2.id)).isFalse
    }

    @Test
    fun `only admin can add manager`() {
        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/teams/manage/{teamId}/manager", TestData.team.id!!)
                .param("memberId", TestData.member2.id!!.toString())
                .withAuth(TestData.member)
        )
            .andExpect(status().isUnauthorized)
    }

    private fun setTeamAdmin(memberId: Long) {
        val team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        val member = memberRepository.findById(memberId).orElseThrow()
        team.changeAdmin(member)
        teamRepository.save(team)
        em.flush()
        em.clear()
    }
}
