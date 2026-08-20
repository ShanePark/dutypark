package com.tistory.shanepark.dutypark.report.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.member.block.repository.MemberBlockRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.report.domain.dto.CreateReportRequest
import com.tistory.shanepark.dutypark.report.domain.entity.ContentReport
import com.tistory.shanepark.dutypark.report.domain.enums.ReportReason
import com.tistory.shanepark.dutypark.report.domain.enums.ReportStatus
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
import org.springframework.restdocs.request.RequestDocumentation.parameterWithName
import org.springframework.restdocs.request.RequestDocumentation.pathParameters
import org.springframework.restdocs.request.RequestDocumentation.queryParameters
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.util.UUID

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

    @Test
    fun `reporter reads own reports in created date desc order`() {
        val firstId = createReport(TestData.member, TestData.member2, ReportReason.SPAM, detail = "Posts spam links")
        val otherMemberReportId = createReport(TestData.member2, TestData.member, ReportReason.HARASSMENT)
        val latestId = createReport(TestData.member, TestData.admin, ReportReason.OTHER, detail = "Impersonates staff")
        em.flush()
        em.clear()

        val response = mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/reports/me")
                .param("page", "0")
                .param("size", "10")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.totalElements").value(2))
            .andExpect(jsonPath("$.content[0].id").value(latestId))
            .andExpect(jsonPath("$.content[0].reason").value("OTHER"))
            .andExpect(jsonPath("$.content[0].detail").value("Impersonates staff"))
            .andExpect(jsonPath("$.content[0].status").value("OPEN"))
            .andExpect(jsonPath("$.content[0].reportedMemberName").value(TestData.admin.name))
            .andExpect(jsonPath("$.content[1].id").value(firstId))
            .andDo(
                document(
                    "reports/my-list",
                    queryParameters(
                        parameterWithName("page").description("Page number (0 based)"),
                        parameterWithName("size").description("Page size"),
                    ),
                    responseFields(
                        fieldWithPath("content").description("Reports the caller filed"),
                        fieldWithPath("content[].id").description("Report ID"),
                        fieldWithPath("content[].targetType").description("Reported target type (`MEMBER`, `SCHEDULE`, `TODO`)"),
                        fieldWithPath("content[].reportedMemberName").description("Reported member name captured when the report was filed"),
                        fieldWithPath("content[].reason").description("Report reason"),
                        fieldWithPath("content[].detail").optional().description("Free-form detail the reporter wrote"),
                        fieldWithPath("content[].status").description("Handling status (`OPEN`, `RESOLVED`, `DISMISSED`, `CANCELED`)"),
                        fieldWithPath("content[].createdAt").description("Filed at"),
                        fieldWithPath("content[].resolvedAt").optional()
                            .description("Handled or withdrawn at (null while open)"),
                        fieldWithPath("totalPages").description("Total page count"),
                        fieldWithPath("totalElements").description("Total element count"),
                        fieldWithPath("first").description("Whether this is the first page"),
                        fieldWithPath("last").description("Whether this is the last page"),
                        fieldWithPath("size").description("Page size"),
                        fieldWithPath("number").description("Current page number"),
                        fieldWithPath("numberOfElements").description("Element count on this page"),
                        fieldWithPath("empty").description("Whether the page is empty"),
                        fieldWithPath("pageable").description("Page information"),
                        fieldWithPath("pageable.pageNumber").description("Page number"),
                        fieldWithPath("pageable.pageSize").description("Page size"),
                        fieldWithPath("pageable.sort").description("Sort information"),
                        fieldWithPath("pageable.sort.empty").description("Whether sorting is absent"),
                        fieldWithPath("pageable.sort.sorted").description("Whether sorted"),
                        fieldWithPath("pageable.sort.unsorted").description("Whether unsorted"),
                        fieldWithPath("pageable.offset").description("Offset"),
                        fieldWithPath("pageable.paged").description("Whether paged"),
                        fieldWithPath("pageable.unpaged").description("Whether unpaged"),
                    )
                )
            )
            .andReturn().response.contentAsString

        // The reporter must never see the moderation trail or the evidence snapshot.
        assertThat(response).doesNotContain(
            "adminMemo",
            "resolvedBy",
            "contentSnapshot",
            "snapshotPreview",
            "reporterName",
            "targetId",
        )
        assertThat(response).doesNotContain(otherMemberReportId)
    }

    @Test
    fun `my report list requires login`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/reports/me")
                .accept(MediaType.APPLICATION_JSON)
        )
            .andExpect(status().isUnauthorized)
    }

    @Test
    fun `my report list is paged`() {
        createReport(TestData.member, TestData.member2, ReportReason.SPAM)
        createReport(TestData.member, TestData.admin, ReportReason.HARASSMENT)
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/reports/me")
                .param("page", "1")
                .param("size", "1")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.totalElements").value(2))
            .andExpect(jsonPath("$.totalPages").value(2))
            .andExpect(jsonPath("$.numberOfElements").value(1))
            .andExpect(jsonPath("$.content[0].reportedMemberName").value(TestData.member2.name))
    }

    @Test
    fun `reporter cancels own open report`() {
        val reportId = createReport(TestData.member, TestData.member2, ReportReason.SPAM, detail = "Posts spam links")
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/reports/{reportId}/cancel", reportId)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.id").value(reportId))
            .andExpect(jsonPath("$.status").value("CANCELED"))
            .andExpect(jsonPath("$.resolvedAt").isNotEmpty)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "reports/cancel",
                    pathParameters(parameterWithName("reportId").description("Report ID to withdraw")),
                    responseFields(
                        fieldWithPath("id").description("Report ID"),
                        fieldWithPath("targetType").description("Reported target type (`MEMBER`, `SCHEDULE`, `TODO`)"),
                        fieldWithPath("reportedMemberName").description("Reported member name captured when the report was filed"),
                        fieldWithPath("reason").description("Report reason"),
                        fieldWithPath("detail").optional().description("Free-form detail the reporter wrote"),
                        fieldWithPath("status").description("Handling status, always `CANCELED` here"),
                        fieldWithPath("createdAt").description("Filed at"),
                        fieldWithPath("resolvedAt").description("Withdrawn at"),
                    )
                )
            )
    }

    @Test
    fun `cancel keeps the report as evidence`() {
        val reportId = createReport(TestData.member, TestData.member2, ReportReason.SPAM)
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/reports/{reportId}/cancel", reportId)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)

        assertThat(contentReportRepository.findAll()).hasSize(1)
    }

    @Test
    fun `cancel a report filed by someone else returns not found`() {
        val reportId = createReport(TestData.member2, TestData.member, ReportReason.HARASSMENT)
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/reports/{reportId}/cancel", reportId)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isNotFound)
            .andExpect(jsonPath("$.code").value("common.notFound"))
    }

    @Test
    fun `cancel an unknown report returns not found`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/reports/{reportId}/cancel", UUID.randomUUID())
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isNotFound)
            .andExpect(jsonPath("$.code").value("common.notFound"))
    }

    @Test
    fun `cancel a report that is no longer open returns bad request`() {
        val reportId = createReport(
            TestData.member,
            TestData.member2,
            ReportReason.SPAM,
            status = ReportStatus.RESOLVED,
        )
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/reports/{reportId}/cancel", reportId)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("report.cancel.notOpen"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "reports/cancel-not-open",
                    standardErrorResponseFields("Machine-readable error code (`report.cancel.notOpen`)")
                )
            )
    }

    @Test
    fun `cancel without login is unauthorized`() {
        val reportId = createReport(TestData.member, TestData.member2, ReportReason.SPAM)
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/reports/{reportId}/cancel", reportId)
                .accept(MediaType.APPLICATION_JSON)
        )
            .andExpect(status().isUnauthorized)
    }

    private fun createReport(
        reporter: Member,
        reported: Member,
        reason: ReportReason,
        detail: String? = null,
        status: ReportStatus = ReportStatus.OPEN,
    ): String {
        val report = ContentReport(
            reporter = reporter,
            reportedMember = reported,
            targetType = ReportTargetType.MEMBER,
            targetId = reported.id!!.toString(),
            reason = reason,
            detail = detail,
            contentSnapshot = "이름: ${reported.name}",
            reporterName = reporter.name,
            reportedMemberName = reported.name,
        )
        report.status = status
        return contentReportRepository.save(report).id.toString()
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
