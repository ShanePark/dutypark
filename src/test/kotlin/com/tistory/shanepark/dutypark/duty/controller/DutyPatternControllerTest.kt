package com.tistory.shanepark.dutypark.duty.controller

import com.tistory.shanepark.dutypark.RestDocsTest
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

    @Test
    fun `create and get my duty pattern`() {
        val request = """
            {
              "days": [
                { "weekday": "FRIDAY", "dutyTypeId": ${TestData.dutyTypes[0].id} },
                { "weekday": "SATURDAY", "dutyTypeId": ${TestData.dutyTypes[1].id} },
                { "weekday": "SUNDAY", "dutyTypeId": ${TestData.dutyTypes[1].id} }
              ],
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
            .andExpect(jsonPath("$.dutyTypes.length()").value(TestData.dutyTypes.size))
            .andExpect(jsonPath("$.pattern.days.length()").value(3))
            .andExpect(jsonPath("$.pattern.days[0].dutyType.id").value(TestData.dutyTypes[0].id))
            .andExpect(jsonPath("$.pattern.days[1].dutyType.id").value(TestData.dutyTypes[1].id))
            .andDo(
                document(
                    "duty-pattern/update-mine",
                    requestFields(
                        fieldWithPath("days").description("Weekday-specific duty type assignments"),
                        fieldWithPath("days[].weekday").description("Working weekday"),
                        fieldWithPath("days[].dutyTypeId").description("Visible duty type selected for the weekday"),
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
                .content("""{"days":[{"weekday":"MONDAY","dutyTypeId":${TestData.dutyTypes[0].id}}],"holidayOff":true}""")
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
            .andExpect(jsonPath("$.dutyTypes").isEmpty)
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
    fun `multiple visible duty types remain configurable`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/duty/pattern/me")
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.configurable").value(true))
            .andExpect(jsonPath("$.reason").doesNotExist())
            .andExpect(jsonPath("$.dutyTypes.length()").value(TestData.dutyTypes.size))
    }

    @Test
    fun `update rejects an empty weekday set`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/duty/pattern/me")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"days":[],"holidayOff":true}""")
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `update rejects duplicate weekdays`() {
        val dutyTypeId = TestData.dutyTypes[0].id

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/duty/pattern/me")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"days":[{"weekday":"MONDAY","dutyTypeId":$dutyTypeId},{"weekday":"MONDAY","dutyTypeId":$dutyTypeId}],"holidayOff":true}""")
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("duty.pattern.weekdays.duplicate"))
    }

    @Test
    fun `update rejects a weekday without a duty type`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/duty/pattern/me")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"days":[{"weekday":"MONDAY","dutyTypeId":null}],"holidayOff":true}""")
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `update rejects a hidden duty type`() {
        val hidden = TestData.dutyTypes[0]
        hidden.hidden = true
        dutyTypeRepository.save(hidden)
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/duty/pattern/me")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"days":[{"weekday":"MONDAY","dutyTypeId":${hidden.id}}],"holidayOff":true}""")
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("duty.pattern.dutyType.invalid"))
    }

    private fun patternResponseFields() = responseFields(
        fieldWithPath("configurable").description("Whether the saved pattern can currently be edited and automatically applied"),
        fieldWithPath("reason").optional().description("Reason pattern editing is unavailable"),
        subsectionWithPath("dutyTypes").description("Visible team duty types available for weekday assignment"),
        subsectionWithPath("pattern").optional().description("Current personal weekly pattern"),
    )
}
