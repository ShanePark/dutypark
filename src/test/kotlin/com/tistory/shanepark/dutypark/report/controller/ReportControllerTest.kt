package com.tistory.shanepark.dutypark.report.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.member.block.repository.MemberBlockRepository
import com.tistory.shanepark.dutypark.report.domain.dto.CreateReportRequest
import com.tistory.shanepark.dutypark.report.domain.enums.ReportReason
import com.tistory.shanepark.dutypark.report.domain.enums.ReportTargetType
import com.tistory.shanepark.dutypark.report.repository.ContentReportRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.MediaType
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders
import org.springframework.restdocs.payload.JsonFieldType
import org.springframework.restdocs.payload.PayloadDocumentation.fieldWithPath
import org.springframework.restdocs.payload.PayloadDocumentation.requestFields
import org.springframework.restdocs.payload.PayloadDocumentation.responseFields
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

class ReportControllerTest : RestDocsTest() {

    @Autowired
    lateinit var contentReportRepository: ContentReportRepository

    @Autowired
    lateinit var memberBlockRepository: MemberBlockRepository

    @Test
    fun `create report`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/reports")
                .contentType(MediaType.APPLICATION_JSON)
                .accept(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(memberReportRequest(detail = "Posts spam links repeatedly")))
                .withAuth(TestData.member)
        )
            .andExpect(status().isCreated)
            .andExpect(jsonPath("$.id").isNotEmpty)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "reports/create",
                    requestFields(
                        fieldWithPath("targetType").type(JsonFieldType.STRING)
                            .description("Reported target type (`MEMBER`, `SCHEDULE`, `TODO`)"),
                        fieldWithPath("targetId").type(JsonFieldType.STRING)
                            .description("Target identifier. Member ID for `MEMBER`, UUID otherwise"),
                        fieldWithPath("reason").type(JsonFieldType.STRING)
                            .description("Report reason (`SPAM`, `HARASSMENT`, `INAPPROPRIATE_CONTENT`, `IMPERSONATION`, `OTHER`)"),
                        fieldWithPath("detail").type(JsonFieldType.STRING).optional()
                            .description("Optional free-form detail (max 500 chars). Required when reason is `OTHER`"),
                        fieldWithPath("alsoBlock").type(JsonFieldType.BOOLEAN)
                            .description("Whether to also block the reported member"),
                    ),
                    responseFields(
                        fieldWithPath("id").type(JsonFieldType.STRING).description("Created report ID"),
                    )
                )
            )

        assertThat(contentReportRepository.findAll()).hasSize(1)
    }

    @Test
    fun `create report with alsoBlock also blocks the reported member`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/reports")
                .contentType(MediaType.APPLICATION_JSON)
                .accept(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(memberReportRequest(alsoBlock = true)))
                .withAuth(TestData.member)
        )
            .andExpect(status().isCreated)

        assertThat(
            memberBlockRepository.existsByBlockerIdAndBlockedId(TestData.member.id!!, TestData.member2.id!!)
        ).isTrue()
    }

    @Test
    fun `duplicate open report returns ok with the same id`() {
        val firstId = mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/reports")
                .contentType(MediaType.APPLICATION_JSON)
                .accept(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(memberReportRequest()))
                .withAuth(TestData.member)
        )
            .andExpect(status().isCreated)
            .andReturn().response.contentAsString

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/reports")
                .contentType(MediaType.APPLICATION_JSON)
                .accept(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(memberReportRequest()))
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.id").value(objectMapper.readTree(firstId).get("id").stringValue()))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "reports/create-duplicate",
                    responseFields(
                        fieldWithPath("id").type(JsonFieldType.STRING)
                            .description("ID of the already open report for the same target"),
                    )
                )
            )

        assertThat(contentReportRepository.findAll()).hasSize(1)
    }

    @Test
    fun `report own content returns bad request`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/reports")
                .contentType(MediaType.APPLICATION_JSON)
                .accept(MediaType.APPLICATION_JSON)
                .content(
                    objectMapper.writeValueAsString(
                        CreateReportRequest(
                            targetType = ReportTargetType.MEMBER,
                            targetId = TestData.member.id!!.toString(),
                            reason = ReportReason.SPAM,
                            detail = null,
                        )
                    )
                )
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.status").value(400))
            .andExpect(jsonPath("$.code").value("report.self"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "reports/create-self",
                    standardErrorResponseFields("Machine-readable error code (`report.self`)")
                )
            )
    }

    @Test
    fun `OTHER reason without detail returns bad request`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/reports")
                .contentType(MediaType.APPLICATION_JSON)
                .accept(MediaType.APPLICATION_JSON)
                .content(
                    objectMapper.writeValueAsString(memberReportRequest(reason = ReportReason.OTHER))
                )
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("report.detail.required"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "reports/create-detail-required",
                    standardErrorResponseFields("Machine-readable error code (`report.detail.required`)")
                )
            )
    }

    @Test
    fun `report unknown target returns not found`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/reports")
                .contentType(MediaType.APPLICATION_JSON)
                .accept(MediaType.APPLICATION_JSON)
                .content(
                    objectMapper.writeValueAsString(
                        CreateReportRequest(
                            targetType = ReportTargetType.MEMBER,
                            targetId = "-1",
                            reason = ReportReason.SPAM,
                            detail = null,
                        )
                    )
                )
                .withAuth(TestData.member)
        )
            .andExpect(status().isNotFound)
    }

    @Test
    fun `blank targetId returns bad request`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/reports")
                .contentType(MediaType.APPLICATION_JSON)
                .accept(MediaType.APPLICATION_JSON)
                .content(
                    objectMapper.writeValueAsString(
                        CreateReportRequest(
                            targetType = ReportTargetType.MEMBER,
                            targetId = " ",
                            reason = ReportReason.SPAM,
                            detail = null,
                        )
                    )
                )
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `create report without login is unauthorized`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/reports")
                .contentType(MediaType.APPLICATION_JSON)
                .accept(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(memberReportRequest()))
        )
            .andExpect(status().isUnauthorized)
    }

    private fun memberReportRequest(
        reason: ReportReason = ReportReason.SPAM,
        detail: String? = null,
        alsoBlock: Boolean = false,
    ) = CreateReportRequest(
        targetType = ReportTargetType.MEMBER,
        targetId = TestData.member2.id!!.toString(),
        reason = reason,
        detail = detail,
        alsoBlock = alsoBlock,
    )

    private fun standardErrorResponseFields(codeDescription: String) = responseFields(
        fieldWithPath("status").type(JsonFieldType.NUMBER).description("HTTP status code"),
        fieldWithPath("code").type(JsonFieldType.STRING).description(codeDescription),
        fieldWithPath("details").type(JsonFieldType.OBJECT).optional().description("Additional error details"),
        fieldWithPath("fieldErrors").type(JsonFieldType.ARRAY).optional().description("Field validation errors")
    )

}
