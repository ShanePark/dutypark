package com.tistory.shanepark.dutypark.report.controller

import com.tistory.shanepark.dutypark.common.domain.dto.PageResponse
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.report.domain.dto.AdminReportDetailDto
import com.tistory.shanepark.dutypark.report.domain.dto.AdminReportSummaryDto
import com.tistory.shanepark.dutypark.report.domain.dto.UpdateReportStatusRequest
import com.tistory.shanepark.dutypark.report.domain.enums.ReportStatus
import com.tistory.shanepark.dutypark.report.service.AdminReportService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import jakarta.validation.Valid
import org.springframework.data.domain.Pageable
import org.springframework.data.web.PageableDefault
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PatchMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.util.*

@RestController
@RequestMapping("/admin/api/reports")
class AdminReportController(
    private val adminReportService: AdminReportService,
) {

    @GetMapping
    fun findReports(
        @RequestParam(required = false) status: String?,
        @PageableDefault(size = 10) pageable: Pageable,
    ): PageResponse<AdminReportSummaryDto> {
        return PageResponse(adminReportService.findReports(parseStatus(status), pageable))
    }

    @GetMapping("/{reportId}")
    fun findReport(
        @PathVariable reportId: UUID,
    ): AdminReportDetailDto {
        return adminReportService.findReport(reportId)
    }

    @PatchMapping("/{reportId}/status")
    fun updateStatus(
        @Login loginMember: LoginMember,
        @PathVariable reportId: UUID,
        @Valid @RequestBody request: UpdateReportStatusRequest,
    ): AdminReportDetailDto {
        return adminReportService.updateStatus(
            reportId = reportId,
            adminMemberId = loginMember.id,
            request = request,
        )
    }

    @DeleteMapping("/{reportId}/target")
    fun deleteTarget(
        @PathVariable reportId: UUID,
    ): AdminReportDetailDto {
        return adminReportService.deleteTarget(reportId)
    }

    /** An omitted or `ALL` status means "every report"; anything else must name a [ReportStatus]. */
    private fun parseStatus(status: String?): ReportStatus? {
        val value = status?.trim().orEmpty()
        if (value.isEmpty() || value.equals(ALL_STATUSES, ignoreCase = true)) {
            return null
        }
        return ReportStatus.valueOf(value.uppercase())
    }

    companion object {
        private const val ALL_STATUSES = "ALL"
    }

}
