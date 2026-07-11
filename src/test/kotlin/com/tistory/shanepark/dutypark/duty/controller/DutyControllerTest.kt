package com.tistory.shanepark.dutypark.duty.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.MediaType
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders
import org.springframework.restdocs.payload.PayloadDocumentation.*
import org.springframework.restdocs.request.RequestDocumentation.parameterWithName
import org.springframework.restdocs.request.RequestDocumentation.queryParameters
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.time.LocalDate

class DutyControllerTest : RestDocsTest() {

    private val fixedDate = LocalDate.of(2025, 1, 15)

    @Autowired
    lateinit var dutyRepository: DutyRepository

    @Test
    fun `get duties for member`() {
        val today = fixedDate
        dutyRepository.save(
            Duty(
                dutyDate = today,
                dutyType = TestData.dutyTypes[0],
                member = TestData.member
            )
        )

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/duty")
                .param("year", today.year.toString())
                .param("month", today.monthValue.toString())
                .param("memberId", TestData.member.id.toString())
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "duty/get-list",
                    queryParameters(
                        parameterWithName("year").description("Year"),
                        parameterWithName("month").description("Month"),
                        parameterWithName("memberId").description("Member ID")
                    ),
                    responseFields(
                        fieldWithPath("[].year").description("Year"),
                        fieldWithPath("[].month").description("Month"),
                        fieldWithPath("[].day").description("Day of month"),
                        fieldWithPath("[].dutyType").description("Duty type name (null if off)"),
                        fieldWithPath("[].dutyColor").description("Duty type color (hex)"),
                        fieldWithPath("[].isOff").description("Whether this day is off"),
                        fieldWithPath("[].dutyTypeId").optional().description("Duty type ID"),
                        fieldWithPath("[].source").description("Resolved duty source, including PATTERN_PAUSED when the saved pattern has no single visible duty type"),
                    )
                )
            )
    }

    @Test
    fun `get others duties`() {
        val today = fixedDate
        makeThemFriend(TestData.member, TestData.member2)

        dutyRepository.save(
            Duty(
                dutyDate = today,
                dutyType = TestData.dutyTypes[0],
                member = TestData.member2
            )
        )

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/duty/others")
                .param("year", today.year.toString())
                .param("month", today.monthValue.toString())
                .param("memberIds", TestData.member2.id.toString())
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("[0].memberId").value(TestData.member2.id))
            .andExpect(jsonPath("[0].name").value(TestData.member2.name))
            .andExpect(jsonPath("[0].hasProfilePhoto").value(false))
            .andExpect(jsonPath("[0].profilePhotoVersion").value(0))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "duty/get-others",
                    queryParameters(
                        parameterWithName("year").description("Year"),
                        parameterWithName("month").description("Month"),
                        parameterWithName("memberIds").description("List of member IDs to fetch duties for")
                    ),
                    responseFields(
                        fieldWithPath("[].memberId").description("Member ID"),
                        fieldWithPath("[].name").description("Member name"),
                        fieldWithPath("[].hasProfilePhoto").description("Whether the member has a profile photo"),
                        fieldWithPath("[].profilePhotoVersion").description("Profile photo cache-busting version"),
                        fieldWithPath("[].duties").description("List of duties"),
                        fieldWithPath("[].duties[].year").description("Year"),
                        fieldWithPath("[].duties[].month").description("Month"),
                        fieldWithPath("[].duties[].day").description("Day of month"),
                        fieldWithPath("[].duties[].dutyType").description("Duty type name"),
                        fieldWithPath("[].duties[].dutyColor").description("Duty type color"),
                        fieldWithPath("[].duties[].isOff").description("Whether this day is off"),
                        fieldWithPath("[].duties[].dutyTypeId").optional().description("Duty type ID"),
                        fieldWithPath("[].duties[].source").description("Resolved duty source, including PATTERN_PAUSED when the saved pattern has no single visible duty type"),
                    )
                )
            )
    }

    @Test
    fun `update single duty`() {
        val today = fixedDate
        val json = """
            {
                "year": ${today.year},
                "month": ${today.monthValue},
                "day": ${today.dayOfMonth},
                "dutyTypeId": ${TestData.dutyTypes[0].id},
                "memberId": ${TestData.member.id}
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/duty/change")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$").value(true))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "duty/update",
                    requestFields(
                        fieldWithPath("year").description("Year"),
                        fieldWithPath("month").description("Month"),
                        fieldWithPath("day").description("Day of month"),
                        fieldWithPath("dutyTypeId").description("Duty type ID (null for off day)"),
                        fieldWithPath("memberId").description("Member ID")
                    )
                )
            )
    }

    @Test
    fun `batch update duties for month`() {
        val today = fixedDate
        val json = """
            {
                "year": ${today.year},
                "month": ${today.monthValue},
                "dutyTypeId": ${TestData.dutyTypes[1].id},
                "memberId": ${TestData.member.id}
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/duty/batch")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$").value(true))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "duty/batch-update",
                    requestFields(
                        fieldWithPath("year").description("Year"),
                        fieldWithPath("month").description("Month"),
                        fieldWithPath("dutyTypeId").description("Duty type ID to apply to all days (null for all off)"),
                        fieldWithPath("memberId").description("Member ID")
                    )
                )
            )
    }

    @Test
    fun `update duty unauthorized`() {
        val today = fixedDate
        val json = """
            {
                "year": ${today.year},
                "month": ${today.monthValue},
                "day": ${today.dayOfMonth},
                "dutyTypeId": ${TestData.dutyTypes[0].id},
                "memberId": ${TestData.member.id}
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/duty/change")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isUnauthorized)
            .andDo(MockMvcResultHandlers.print())
            .andDo(document("duty/update-unauthorized"))
    }

    @Test
    fun `reset duty override to pattern`() {
        val today = fixedDate
        dutyRepository.save(Duty(today, TestData.dutyTypes[0], TestData.member))

        mockMvc.perform(
            RestDocumentationRequestBuilders.delete("/api/duty/override")
                .queryParam("memberId", TestData.member.id.toString())
                .queryParam("date", today.toString())
                .withAuth(TestData.member)
        )
            .andExpect(status().isNoContent)
            .andDo(
                document(
                    "duty/reset-override",
                    queryParameters(
                        parameterWithName("memberId").description("Member ID"),
                        parameterWithName("date").description("Date to return to pattern inheritance"),
                    )
                )
            )
    }

    @Test
    fun `reset duty override is forbidden for a member without edit permission`() {
        val today = fixedDate
        dutyRepository.save(Duty(today, TestData.dutyTypes[0], TestData.member))

        mockMvc.perform(
            RestDocumentationRequestBuilders.delete("/api/duty/override")
                .queryParam("memberId", TestData.member.id.toString())
                .queryParam("date", today.toString())
                .withAuth(TestData.member2)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("duty.edit.forbidden"))

        val override = dutyRepository.findByMemberAndDutyDate(TestData.member, today)
        org.assertj.core.api.Assertions.assertThat(override).isNotNull
    }

    @Test
    fun `reset duty override requires authentication`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.delete("/api/duty/override")
                .queryParam("memberId", TestData.member.id.toString())
                .queryParam("date", fixedDate.toString())
        )
            .andExpect(status().isUnauthorized)
    }

    @Test
    fun `update duty forbidden for other member`() {
        val today = fixedDate
        val json = """
            {
                "year": ${today.year},
                "month": ${today.monthValue},
                "day": ${today.dayOfMonth},
                "dutyTypeId": ${TestData.dutyTypes[0].id},
                "memberId": ${TestData.member.id}
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/duty/change")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member2)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("duty.edit.forbidden"))
            .andDo(MockMvcResultHandlers.print())
    }

}
