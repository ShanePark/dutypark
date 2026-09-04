package com.tistory.shanepark.dutypark.team.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.team.domain.dto.TeamCreateDto
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.MediaType
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders
import org.springframework.restdocs.payload.PayloadDocumentation.*
import org.springframework.restdocs.request.RequestDocumentation.*
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.time.LocalDate

class TeamControllerTest : RestDocsTest() {

    @Autowired
    lateinit var dutyRepository: DutyRepository

    private val fixedDate = LocalDate.of(2025, 1, 15)

    @Test
    fun `member can create a team and becomes its admin`() {
        val member = memberRepository.save(Member(name = "new member", email = "new-member@duty.park"))
        val json = objectMapper.writeValueAsString(TeamCreateDto("new team", "description"))

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/teams")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.name").value("new team"))
            .andExpect(jsonPath("$.adminId").value(member.id))
            .andExpect(jsonPath("$.adminName").value(member.name))
            .andExpect(jsonPath("$.dutyTypes[0].name").value("OFF"))
            .andExpect(jsonPath("$.dutyTypes[1].name").value("WORK"))
            .andExpect(jsonPath("$.dutyTypes[1].position").value(0))
            .andExpect(jsonPath("$.dutyTypes[1].color").value("#98fb98"))
            .andExpect(jsonPath("$.dutyTypes[1].hidden").value(false))

        val created = teamRepository.findByName("new team")
        assertThat(created).isNotNull
        assertThat(created!!.admin?.id).isEqualTo(member.id)
        assertThat(memberRepository.findById(member.id!!).orElseThrow().team?.id).isEqualTo(created.id)
        val workDutyType = dutyTypeRepository.findAllByTeam(created).single()
        assertThat(workDutyType.id).isNotNull
        assertThat(workDutyType.name).isEqualTo("WORK")
        assertThat(workDutyType.position).isEqualTo(0)
        assertThat(workDutyType.color).isEqualTo("#98fb98")
        assertThat(workDutyType.hidden).isFalse
    }

    @Test
    fun `member cannot create a team with a banned name`() {
        val member = memberRepository.save(Member(name = "new member", email = "blocked-name@duty.park"))
        val json = objectMapper.writeValueAsString(TeamCreateDto("  시.발  ", ""))

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/teams")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("contentFilter.blocked"))

        assertThat(teamRepository.findByName("시.발")).isNull()
    }

    @Test
    fun `member cannot create a team with a banned description`() {
        val member = memberRepository.save(Member(name = "new member", email = "blocked-description@duty.park"))
        val json = objectMapper.writeValueAsString(TeamCreateDto("clean team", "시.발"))

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/teams")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("contentFilter.blocked"))

        assertThat(teamRepository.findByName("clean team")).isNull()
    }

    @Test
    fun `member team name check returns duplicated`() {
        val member = memberRepository.save(Member(name = "new member", email = "new-member@duty.park"))

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/teams/check")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"name":"${TestData.team.name}"}""")
                .withAuth(member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$").value("DUPLICATED"))
    }

    @Test
    fun `member team name check trims the name before checking`() {
        val member = memberRepository.save(Member(name = "new member", email = "new-member@duty.park"))

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/teams/check")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"name":"  ${TestData.team.name}  "}""")
                .withAuth(member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$").value("DUPLICATED"))
    }

    @Test
    fun `member team creation trims the saved name`() {
        val member = memberRepository.save(Member(name = "new member", email = "new-member@duty.park"))
        val json = objectMapper.writeValueAsString(TeamCreateDto("  trimmed team  ", "description"))

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/teams")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.name").value("trimmed team"))

        assertThat(teamRepository.findByName("trimmed team")).isNotNull
        assertThat(teamRepository.findByName("  trimmed team  ")).isNull()
    }

    @Test
    fun `member cannot create a whitespace-only team name`() {
        val member = memberRepository.save(Member(name = "new member", email = "new-member@duty.park"))
        val json = objectMapper.writeValueAsString(TeamCreateDto("  ", ""))

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/teams")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("team.name.length"))
    }

    @Test
    fun `team name check requires authentication`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/teams/check")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"name":"new team"}""")
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("auth.required"))
    }

    @Test
    fun `member cannot create a team when already assigned`() {
        val json = objectMapper.writeValueAsString(TeamCreateDto("new team", ""))

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/teams")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("team.member.alreadyAssigned"))
    }

    @Test
    fun `get team by id`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/teams/{id}", TestData.team.id!!)
                .accept(MediaType.APPLICATION_JSON)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.id").value(TestData.team.id))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "teams/get-by-id",
                    pathParameters(
                        parameterWithName("id").description("Team ID")
                    ),
                    responseFields(
                        fieldWithPath("id").description("Team ID"),
                        fieldWithPath("name").description("Team name"),
                        fieldWithPath("description").description("Team description"),
                        subsectionWithPath("dutyTypes").description("List of duty types"),
                        fieldWithPath("members").description("Team members"),
                        fieldWithPath("createdDate").description("Created date"),
                        fieldWithPath("lastModifiedDate").description("Last modified date"),
                        fieldWithPath("adminId").description("Admin member ID"),
                        fieldWithPath("adminName").description("Admin member name"),
                        fieldWithPath("dutyBatchTemplate").description("Duty batch template (nullable)")
                    )
                )
            )
    }

    @Test
    fun `get my team summary`() {
        val today = fixedDate

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/teams/my")
                .param("year", today.year.toString())
                .param("month", today.monthValue.toString())
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "teams/my-summary",
                    queryParameters(
                        parameterWithName("year").description("Year"),
                        parameterWithName("month").description("Month")
                    ),
                    responseFields(
                        fieldWithPath("year").description("Year"),
                        fieldWithPath("month").description("Month"),
                        subsectionWithPath("team").description("Team info"),
                        fieldWithPath("teamDays").description("Team days array"),
                        fieldWithPath("teamDays[].year").description("Year"),
                        fieldWithPath("teamDays[].month").description("Month"),
                        fieldWithPath("teamDays[].day").description("Day"),
                        fieldWithPath("isTeamManager").description("Is current user team manager")
                    )
                )
            )
    }

    @Test
    fun `get shift for day`() {
        val today = fixedDate
        dutyRepository.save(
            Duty(
                dutyDate = today,
                dutyType = TestData.dutyTypes[0],
                member = TestData.member
            )
        )
        dutyRepository.save(
            Duty(
                dutyDate = today,
                dutyType = TestData.dutyTypes[1],
                member = TestData.member2
            )
        )

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/teams/shift")
                .param("year", today.year.toString())
                .param("month", today.monthValue.toString())
                .param("day", today.dayOfMonth.toString())
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "teams/shift",
                    queryParameters(
                        parameterWithName("year").description("Year"),
                        parameterWithName("month").description("Month"),
                        parameterWithName("day").description("Day")
                    ),
                    responseFields(
                        subsectionWithPath("[].dutyType").description("Duty type information"),
                        fieldWithPath("[].members").description("Members assigned to the duty type"),
                        fieldWithPath("[].members[].id").description("Member ID"),
                        fieldWithPath("[].members[].name").description("Member name"),
                        fieldWithPath("[].members[].teamId").description("Member team ID (nullable)"),
                        fieldWithPath("[].members[].team").description("Member team name (nullable)"),
                        fieldWithPath("[].members[].hasProfilePhoto").description("Whether member has profile photo"),
                        fieldWithPath("[].members[].profilePhotoVersion").description("Profile photo version for cache busting"),
                    )
                )
            )
    }

}
