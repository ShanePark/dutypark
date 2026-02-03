package com.tistory.shanepark.dutypark.team.controller

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.team.domain.dto.TeamCreateDto
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

@AutoConfigureMockMvc
class TeamAdminControllerTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var mockMvc: MockMvc

    @Test
    fun `admin can search teams with keyword`() {
        mockMvc.perform(
            MockMvcRequestBuilders.get("/admin/api/teams")
                .param("keyword", TestData.team.name)
                .param("page", "0")
                .param("size", "10")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.admin)}")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.content.length()").value(1))
            .andExpect(jsonPath("$.content[0].name").value(TestData.team.name))
    }

    @Test
    fun `non-admin cannot create team`() {
        val payload = TeamCreateDto(name = "new-team", description = "desc")
        val json = objectMapper.writeValueAsString(payload)

        mockMvc.perform(
            MockMvcRequestBuilders.post("/admin/api/teams")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.member)}")
        )
            .andExpect(status().isUnauthorized)
    }

    @Test
    fun `admin can create team`() {
        val payload = TeamCreateDto(name = "new-team", description = "desc")
        val json = objectMapper.writeValueAsString(payload)

        mockMvc.perform(
            MockMvcRequestBuilders.post("/admin/api/teams")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.admin)}")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.name").value("new-team"))

        val saved = teamRepository.findByName("new-team")
        assertThat(saved).isNotNull
    }

    @Test
    fun `team create validation fails for short name`() {
        val payload = TeamCreateDto(name = "a", description = "desc")
        val json = objectMapper.writeValueAsString(payload)

        mockMvc.perform(
            MockMvcRequestBuilders.post("/admin/api/teams")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.admin)}")
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `team name check returns too short`() {
        mockMvc.perform(
            MockMvcRequestBuilders.post("/admin/api/teams/check")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"name":"a"}""")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.admin)}")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$").value("TOO_SHORT"))
    }

    @Test
    fun `team name check returns too long`() {
        val longName = "a".repeat(21)
        mockMvc.perform(
            MockMvcRequestBuilders.post("/admin/api/teams/check")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"name":"$longName"}""")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.admin)}")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$").value("TOO_LONG"))
    }

    @Test
    fun `team name check returns duplicated`() {
        mockMvc.perform(
            MockMvcRequestBuilders.post("/admin/api/teams/check")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"name":"${TestData.team.name}"}""")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.admin)}")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$").value("DUPLICATED"))
    }

    @Test
    fun `team name check returns ok`() {
        mockMvc.perform(
            MockMvcRequestBuilders.post("/admin/api/teams/check")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"name":"valid-team"}""")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.admin)}")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$").value("OK"))
    }

    @Test
    fun `admin can delete empty team`() {
        val team = teamRepository.save(Team("temp-team"))

        mockMvc.perform(
            MockMvcRequestBuilders.delete("/admin/api/teams/{id}", team.id!!)
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.admin)}")
        )
            .andExpect(status().isOk)

        assertThat(teamRepository.findById(team.id!!)).isEmpty
    }

    @Test
    fun `delete fails for team with members`() {
        val thrown = assertThrows<jakarta.servlet.ServletException> {
            mockMvc.perform(
                MockMvcRequestBuilders.delete("/admin/api/teams/{id}", TestData.team.id!!)
                    .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.admin)}")
            ).andReturn()
        }

        assertThat(thrown.rootCause).isInstanceOf(IllegalStateException::class.java)
    }
}
