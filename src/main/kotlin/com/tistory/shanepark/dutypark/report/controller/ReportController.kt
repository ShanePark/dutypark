package com.tistory.shanepark.dutypark.report.controller

import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.report.domain.dto.CreateReportRequest
import com.tistory.shanepark.dutypark.report.domain.dto.ReportIdResponse
import com.tistory.shanepark.dutypark.report.service.ReportService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/reports")
class ReportController(
    private val reportService: ReportService,
) {

    @PostMapping
    fun createReport(
        @Login loginMember: LoginMember,
        @Valid @RequestBody request: CreateReportRequest,
    ): ResponseEntity<ReportIdResponse> {
        val result = reportService.createReport(loginMember.id, request)
        val status = if (result.isNew) HttpStatus.CREATED else HttpStatus.OK
        return ResponseEntity.status(status).body(ReportIdResponse(result.id))
    }

}
