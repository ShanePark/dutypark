package com.tistory.shanepark.dutypark.report.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.report.domain.dto.UpdateReportStatusRequest
import com.tistory.shanepark.dutypark.report.domain.entity.ContentReport
import com.tistory.shanepark.dutypark.report.domain.enums.ReportReason
import com.tistory.shanepark.dutypark.report.domain.enums.ReportStatus
import com.tistory.shanepark.dutypark.report.domain.enums.ReportTargetType
import com.tistory.shanepark.dutypark.report.repository.ContentReportRepository
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
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
import org.springframework.restdocs.payload.PayloadDocumentation.subsectionWithPath
import org.springframework.restdocs.request.RequestDocumentation.parameterWithName
import org.springframework.restdocs.request.RequestDocumentation.pathParameters
import org.springframework.restdocs.request.RequestDocumentation.queryParameters
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.time.LocalDateTime

class AdminReportControllerTest : RestDocsTest() {

    @Autowired
    lateinit var contentReportRepository: ContentReportRepository

    @Autowired
    lateinit var scheduleRepository: ScheduleRepository

    @Test
    fun `admin report list`() {
        saveReport()
        saveReport(status = ReportStatus.RESOLVED)
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/admin/api/reports")
                .param("status", "OPEN")
                .param("page", "0")
                .param("size", "10")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.admin)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.totalElements").value(1))
            .andExpect(jsonPath("$.content[0].status").value("OPEN"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "admin/reports-list",
                    queryParameters(
                        parameterWithName("status").optional()
                            .description("Report status filter (`OPEN`, `RESOLVED`, `DISMISSED`). Omitted or `ALL` returns every report"),
                        parameterWithName("page").optional().description("Page number (0-based)"),
                        parameterWithName("size").optional().description("Page size (default 10)"),
                    ),
                    responseFields(
                        fieldWithPath("content").description("Reports, newest first"),
                        fieldWithPath("content[].id").description("Report ID"),
                        fieldWithPath("content[].targetType").description("Reported target type (`MEMBER`, `SCHEDULE`, `TODO`)"),
                        fieldWithPath("content[].targetId").description("Target identifier"),
                        fieldWithPath("content[].reason").description("Report reason"),
                        fieldWithPath("content[].status").description("Report status"),
                        fieldWithPath("content[].createdAt").description("Report submission time"),
                        subsectionWithPath("content[].reporter").optional()
                            .description("Reporter account, or null once the account is deleted"),
                        subsectionWithPath("content[].reportedMember").optional()
                            .description("Reported account, or null once the account is deleted"),
                        fieldWithPath("content[].reporterName").description("Reporter name captured when the report was filed"),
                        fieldWithPath("content[].reportedMemberName").description("Reported member name captured when the report was filed"),
                        fieldWithPath("content[].snapshotPreview").description("First line of the content snapshot, max 100 chars"),
                        fieldWithPath("totalPages").description("Total pages"),
                        fieldWithPath("totalElements").description("Total elements"),
                        fieldWithPath("first").description("Is first page"),
                        fieldWithPath("last").description("Is last page"),
                        fieldWithPath("size").description("Page size"),
                        fieldWithPath("number").description("Current page number"),
                        fieldWithPath("numberOfElements").description("Number of elements in current page"),
                        fieldWithPath("empty").description("Is empty"),
                        subsectionWithPath("pageable").description("Pageable info"),
                    )
                )
            )
    }

    @Test
    fun `admin report list without status returns every report`() {
        saveReport()
        saveReport(status = ReportStatus.DISMISSED)
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/admin/api/reports")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.admin)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.totalElements").value(2))
    }

    @Test
    fun `admin report list with ALL status returns every report`() {
        saveReport()
        saveReport(status = ReportStatus.RESOLVED)
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/admin/api/reports")
                .param("status", "ALL")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.admin)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.totalElements").value(2))
    }

    @Test
    fun `admin report detail`() {
        val report = saveReport(detail = "Keeps sending spam links")
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/admin/api/reports/{reportId}", report.id)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.admin)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.detail").value("Keeps sending spam links"))
            .andExpect(jsonPath("$.targetExists").value(true))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "admin/reports-detail",
                    pathParameters(parameterWithName("reportId").description("Report ID")),
                    detailResponseFields(),
                )
            )
    }

    @Test
    fun `admin resolves a report`() {
        val report = saveReport()
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.patch("/admin/api/reports/{reportId}/status", report.id)
                .contentType(MediaType.APPLICATION_JSON)
                .accept(MediaType.APPLICATION_JSON)
                .content(
                    objectMapper.writeValueAsString(
                        UpdateReportStatusRequest(status = ReportStatus.RESOLVED, memo = "Content removed")
                    )
                )
                .withAuth(TestData.admin)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.status").value("RESOLVED"))
            .andExpect(jsonPath("$.adminMemo").value("Content removed"))
            .andExpect(jsonPath("$.resolvedByName").value(TestData.admin.name))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "admin/reports-update-status",
                    pathParameters(parameterWithName("reportId").description("Report ID")),
                    requestFields(
                        fieldWithPath("status").type(JsonFieldType.STRING)
                            .description("New status (`RESOLVED` or `DISMISSED`)"),
                        fieldWithPath("memo").type(JsonFieldType.STRING).optional()
                            .description(
                                "Admin memo (max 1000 chars). Omit to keep the memo already recorded, " +
                                    "send a blank string to clear it"
                            ),
                    ),
                    detailResponseFields(),
                )
            )
    }

    @Test
    fun `admin deletes the reported content`() {
        val schedule = saveSchedule()
        val report = saveReport(
            targetType = ReportTargetType.SCHEDULE,
            targetId = schedule.id.toString(),
        )
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.delete("/admin/api/reports/{reportId}/target", report.id)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.admin)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.targetExists").value(false))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "admin/reports-delete-target",
                    pathParameters(parameterWithName("reportId").description("Report ID")),
                    detailResponseFields(),
                )
            )

        assertThat(scheduleRepository.findById(schedule.id)).isEmpty
    }

    @Test
    fun `admin cannot delete a reported member`() {
        val report = saveReport()
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.delete("/admin/api/reports/{reportId}/target", report.id)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.admin)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("report.target.notDeletable"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "admin/reports-delete-target-not-deletable",
                    responseFields(
                        fieldWithPath("status").type(JsonFieldType.NUMBER).description("HTTP status code"),
                        fieldWithPath("code").type(JsonFieldType.STRING)
                            .description("Machine-readable error code (`report.target.notDeletable`)"),
                        fieldWithPath("details").type(JsonFieldType.OBJECT).optional()
                            .description("Additional error details"),
                        fieldWithPath("fieldErrors").type(JsonFieldType.ARRAY).optional()
                            .description("Field validation errors"),
                    )
                )
            )
    }

    @Test
    fun `deleting an already removed target succeeds`() {
        val schedule = saveSchedule()
        val report = saveReport(
            targetType = ReportTargetType.SCHEDULE,
            targetId = schedule.id.toString(),
        )
        scheduleRepository.delete(schedule)
        em.flush()
        em.clear()

        mockMvc.perform(
            RestDocumentationRequestBuilders.delete("/admin/api/reports/{reportId}/target", report.id)
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.admin)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.targetExists").value(false))
    }

    @Test
    fun `unknown report returns not found`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/admin/api/reports/{reportId}", java.util.UUID.randomUUID())
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.admin)
        )
            .andExpect(status().isNotFound)
    }

    private fun detailResponseFields() = responseFields(
        fieldWithPath("id").description("Report ID"),
        fieldWithPath("targetType").description("Reported target type (`MEMBER`, `SCHEDULE`, `TODO`)"),
        fieldWithPath("targetId").description("Target identifier"),
        fieldWithPath("reason").description("Report reason"),
        fieldWithPath("status").description("Report status"),
        fieldWithPath("createdAt").description("Report submission time"),
        subsectionWithPath("reporter").optional()
            .description("Reporter account, or null once the account is deleted"),
        subsectionWithPath("reportedMember").optional()
            .description("Reported account, or null once the account is deleted"),
        fieldWithPath("reporterName").description("Reporter name captured when the report was filed"),
        fieldWithPath("reportedMemberName").description("Reported member name captured when the report was filed"),
        fieldWithPath("snapshotPreview").description("First line of the content snapshot, max 100 chars"),
        fieldWithPath("detail").type(JsonFieldType.STRING).optional().description("Reporter supplied detail"),
        fieldWithPath("contentSnapshot").description("Content summary captured when the report was filed"),
        fieldWithPath("targetExists").description("Whether the reported content still exists"),
        fieldWithPath("adminMemo").type(JsonFieldType.STRING).optional().description("Admin memo"),
        fieldWithPath("resolvedAt").type(JsonFieldType.STRING).optional().description("Time the report was handled"),
        fieldWithPath("resolvedByName").type(JsonFieldType.STRING).optional()
            .description("Name of the admin who handled the report"),
    )

    private fun saveReport(
        targetType: ReportTargetType = ReportTargetType.MEMBER,
        targetId: String = TestData.member2.id!!.toString(),
        reason: ReportReason = ReportReason.SPAM,
        detail: String? = null,
        status: ReportStatus = ReportStatus.OPEN,
    ): ContentReport {
        val reporter = reload(TestData.member)
        val reported = reload(TestData.member2)
        val report = ContentReport(
            reporter = reporter,
            reportedMember = reported,
            targetType = targetType,
            targetId = targetId,
            reason = reason,
            detail = detail,
            contentSnapshot = "이름: ${reported.name}\n프로필 사진: 없음(version 0)",
            reporterName = reporter.name,
            reportedMemberName = reported.name,
        )
        report.status = status
        return contentReportRepository.save(report)
    }

    private fun saveSchedule(): Schedule {
        return scheduleRepository.save(
            Schedule(
                member = reload(TestData.member2),
                content = "회식",
                description = "설명",
                startDateTime = LocalDateTime.of(2026, 8, 18, 10, 0),
                endDateTime = LocalDateTime.of(2026, 8, 18, 11, 0),
            )
        )
    }

    private fun reload(member: Member): Member = memberRepository.findById(member.id!!).orElseThrow()

}
