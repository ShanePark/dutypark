package com.tistory.shanepark.dutypark.team.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeCreateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.http.MediaType
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.payload.PayloadDocumentation.fieldWithPath
import org.springframework.restdocs.payload.PayloadDocumentation.requestFields
import org.springframework.restdocs.request.RequestDocumentation.parameterWithName
import org.springframework.restdocs.request.RequestDocumentation.pathParameters
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

class TeamManageDutyTypeControllerTest : RestDocsTest() {

    @Test
    fun `manager can add duty type`() {
        setTeamAdmin(TestData.member.id!!)
        val payload = DutyTypeCreateDto(
            teamId = TestData.team.id!!,
            name = "ExtraDuty",
            color = "#123456"
        )
        val json = objectMapper.writeValueAsString(payload)

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/teams/manage/{teamId}/duty-types", TestData.team.id!!)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)

        val names = dutyTypeRepository.findAllByTeam(TestData.team).map { it.name }
        assertThat(names).contains("ExtraDuty")
    }

    @Test
    fun `non-manager cannot add duty type`() {
        val payload = DutyTypeCreateDto(
            teamId = TestData.team.id!!,
            name = "ExtraDuty",
            color = "#123456"
        )
        val json = objectMapper.writeValueAsString(payload)

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/teams/manage/{teamId}/duty-types", TestData.team.id!!)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member2)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("team.manage.forbidden"))
    }

    @Test
    fun `manager can update duty type`() {
        setTeamAdmin(TestData.member.id!!)
        val target = TestData.dutyTypes.first()
        val payload = DutyTypeUpdateDto(
            id = target.id!!,
            name = "UpdatedDy",
            color = "#654321"
        )
        val json = objectMapper.writeValueAsString(payload)

        mockMvc.perform(
            MockMvcRequestBuilders.patch("/api/teams/manage/{teamId}/duty-types", TestData.team.id!!)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)

        val updated = dutyTypeRepository.findById(target.id!!).orElseThrow()
        assertThat(updated.name).isEqualTo("UpdatedDy")
        assertThat(updated.color).isEqualTo("#654321")
    }

    @Test
    fun `update duty type fails on duplicated name`() {
        setTeamAdmin(TestData.member.id!!)
        val dutyType1 = TestData.dutyTypes[0]
        val dutyType2 = TestData.dutyTypes[1]
        val payload = DutyTypeUpdateDto(
            id = dutyType1.id!!,
            name = dutyType2.name,
            color = "#123456"
        )
        val json = objectMapper.writeValueAsString(payload)

        mockMvc.perform(
            MockMvcRequestBuilders.patch("/api/teams/manage/{teamId}/duty-types", TestData.team.id!!)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("dutyType.name.duplicate"))
    }

    @Test
    fun `manager can swap duty type positions`() {
        setTeamAdmin(TestData.member.id!!)
        val dutyType1 = TestData.dutyTypes[0]
        val dutyType2 = TestData.dutyTypes[1]
        val before1 = dutyTypeRepository.findById(dutyType1.id!!).orElseThrow().position
        val before2 = dutyTypeRepository.findById(dutyType2.id!!).orElseThrow().position

        mockMvc.perform(
            MockMvcRequestBuilders.patch("/api/teams/manage/{teamId}/duty-types/swap-position", TestData.team.id!!)
                .param("id1", dutyType1.id!!.toString())
                .param("id2", dutyType2.id!!.toString())
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)

        val after1 = dutyTypeRepository.findById(dutyType1.id!!).orElseThrow().position
        val after2 = dutyTypeRepository.findById(dutyType2.id!!).orElseThrow().position
        assertThat(after1).isEqualTo(before2)
        assertThat(after2).isEqualTo(before1)
    }

    @Test
    fun `swap duty type position fails for different teams`() {
        setTeamAdmin(TestData.member.id!!)
        val team2DutyType = dutyTypeRepository.save(
            DutyType("OtherDuty", 0, TestData.team2, "#111111")
        )

        mockMvc.perform(
            MockMvcRequestBuilders.patch("/api/teams/manage/{teamId}/duty-types/swap-position", TestData.team.id!!)
                .param("id1", TestData.dutyTypes[0].id!!.toString())
                .param("id2", team2DutyType.id!!.toString())
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("team.dutyType.sameTeam.required"))
    }

    @Test
    fun `manager can hide and restore duty type`() {
        setTeamAdmin(TestData.member.id!!)
        val dutyType = dutyTypeRepository.save(
            DutyType("DeleteDuty", 5, TestData.team, "#999999")
        )

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch(
                "/api/teams/manage/{teamId}/duty-types/{id}/visibility",
                TestData.team.id!!,
                dutyType.id!!
            )
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"hidden":true}""")
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andDo(
                document(
                    "teams/duty-types/update-visibility",
                    pathParameters(
                        parameterWithName("teamId").description("Team ID"),
                        parameterWithName("id").description("Duty type ID"),
                    ),
                    requestFields(
                        fieldWithPath("hidden").description("Whether the duty type is hidden"),
                    ),
                )
            )

        assertThat(dutyTypeRepository.findById(dutyType.id!!).orElseThrow().hidden).isTrue()

        mockMvc.perform(
            MockMvcRequestBuilders.patch(
                "/api/teams/manage/{teamId}/duty-types/{id}/visibility",
                TestData.team.id!!,
                dutyType.id!!
            )
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"hidden":false}""")
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)

        assertThat(dutyTypeRepository.findById(dutyType.id!!).orElseThrow().hidden).isFalse()
    }

    @Test
    fun `visibility update rejects a duty type from a different path team`() {
        setTeamAdmin(TestData.member.id!!)
        val team2DutyType = dutyTypeRepository.save(
            DutyType("타팀근무", 0, TestData.team2, "#222222")
        )

        mockMvc.perform(
            MockMvcRequestBuilders.patch(
                "/api/teams/manage/{teamId}/duty-types/{id}/visibility",
                TestData.team.id!!,
                team2DutyType.id!!
            )
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"hidden":true}""")
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)

        assertThat(dutyTypeRepository.findById(team2DutyType.id!!).orElseThrow().hidden).isFalse()
    }

    @Test
    fun `non-manager cannot change duty type visibility`() {
        val dutyType = dutyTypeRepository.save(
            DutyType("보호근무", 5, TestData.team, "#333333")
        )

        mockMvc.perform(
            MockMvcRequestBuilders.patch(
                "/api/teams/manage/{teamId}/duty-types/{id}/visibility",
                TestData.team.id!!,
                dutyType.id!!
            )
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"hidden":true}""")
                .withAuth(TestData.member)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("team.manage.forbidden"))

        assertThat(dutyTypeRepository.findById(dutyType.id!!).orElseThrow().hidden).isFalse()
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
