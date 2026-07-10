package com.tistory.shanepark.dutypark.duty.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.http.MediaType
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders
import org.springframework.restdocs.payload.PayloadDocumentation.fieldWithPath
import org.springframework.restdocs.payload.PayloadDocumentation.requestFields
import org.springframework.restdocs.payload.PayloadDocumentation.responseFields
import org.springframework.restdocs.payload.PayloadDocumentation.subsectionWithPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

class DutyPatternControllerTest : RestDocsTest() {

    @BeforeEach
    fun leaveSingleVisibleDutyType() {
        TestData.dutyTypes.drop(1).forEach {
            it.hidden = true
            dutyTypeRepository.save(it)
        }
        em.flush()
        em.clear()
    }

    @Test
    fun `create and get my duty pattern`() {
        val request = """
            {
              "weekdays": ["FRIDAY", "SATURDAY", "SUNDAY"],
              "holidayOff": true
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/duty/pattern/me")
                .contentType(MediaType.APPLICATION_JSON)
                .content(request)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.configurable").value(true))
            .andExpect(jsonPath("$.pattern.weekdays.length()").value(3))
            .andDo(
                document(
                    "duty-pattern/update-mine",
                    requestFields(
                        fieldWithPath("weekdays").description("Working weekdays"),
                        fieldWithPath("holidayOff").description("Whether public holidays are off"),
                    ),
                    patternResponseFields(),
                )
            )

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/duty/pattern/me")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.pattern.holidayOff").value(true))
            .andDo(document("duty-pattern/get-mine", patternResponseFields()))
    }

    @Test
    fun `delete my duty pattern`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.delete("/api/duty/pattern/me")
                .withAuth(TestData.member)
        )
            .andExpect(status().isNoContent)
            .andDo(document("duty-pattern/delete-mine"))
    }

    @Test
    fun `pattern endpoints require authentication`() {
        mockMvc.perform(RestDocumentationRequestBuilders.get("/api/duty/pattern/me"))
            .andExpect(status().isUnauthorized)

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/duty/pattern/me")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"weekdays":["MONDAY"],"holidayOff":true}""")
        )
            .andExpect(status().isUnauthorized)

        mockMvc.perform(RestDocumentationRequestBuilders.delete("/api/duty/pattern/me"))
            .andExpect(status().isUnauthorized)
    }

    @Test
    fun `get reports that team membership is required`() {
        val team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        team.removeMember(member)
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/duty/pattern/me")
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.configurable").value(false))
            .andExpect(jsonPath("$.reason").value("TEAM_REQUIRED"))
            .andExpect(jsonPath("$.dutyType").doesNotExist())
            .andExpect(jsonPath("$.pattern").doesNotExist())
    }

    @Test
    fun `get reports that a visible duty type is required`() {
        TestData.dutyTypes.forEach {
            it.hidden = true
            dutyTypeRepository.save(it)
        }
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/duty/pattern/me")
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.configurable").value(false))
            .andExpect(jsonPath("$.reason").value("DUTY_TYPE_REQUIRED"))
    }

    @Test
    fun `get reports that exactly one visible duty type is required`() {
        TestData.dutyTypes[1].hidden = false
        dutyTypeRepository.save(TestData.dutyTypes[1])
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/duty/pattern/me")
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.configurable").value(false))
            .andExpect(jsonPath("$.reason").value("SINGLE_DUTY_TYPE_REQUIRED"))
    }

    @Test
    fun `update rejects an empty weekday set`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/duty/pattern/me")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"weekdays":[],"holidayOff":true}""")
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `update rejects a request when visible duty types are not single`() {
        TestData.dutyTypes[1].hidden = false
        dutyTypeRepository.save(TestData.dutyTypes[1])
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/duty/pattern/me")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"weekdays":["MONDAY"],"holidayOff":true}""")
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("duty.pattern.singleDutyType.required"))
    }

    private fun patternResponseFields() = responseFields(
        fieldWithPath("configurable").description("Whether the team has exactly one visible duty type"),
        fieldWithPath("reason").optional().description("Reason pattern editing is unavailable"),
        subsectionWithPath("dutyType").optional().description("The team's single visible duty type"),
        subsectionWithPath("pattern").optional().description("Current personal weekly pattern"),
    )
}
