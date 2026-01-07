package com.tistory.shanepark.dutypark.team.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
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

    @Test
    fun `get team by id`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/teams/{id}", TestData.team.id)
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
                        fieldWithPath("workType").description("Work type (WEEKDAY, FLEXIBLE)"),
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
        val today = LocalDate.now()

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
        val today = LocalDate.now()
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
                        subsectionWithPath("[]").description("List of shifts by duty type")
                    )
                )
            )
    }

}
