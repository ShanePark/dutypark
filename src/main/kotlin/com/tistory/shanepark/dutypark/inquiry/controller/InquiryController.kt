package com.tistory.shanepark.dutypark.inquiry.controller

import com.tistory.shanepark.dutypark.inquiry.domain.dto.CreateInquiryRequest
import com.tistory.shanepark.dutypark.inquiry.domain.dto.CreateInquiryResponse
import com.tistory.shanepark.dutypark.inquiry.service.InquiryService
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import jakarta.servlet.http.HttpServletRequest
import org.springframework.http.HttpStatus
import org.springframework.validation.annotation.Validated
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.ResponseStatus
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/inquiries")
class InquiryController(
    private val inquiryService: InquiryService,
) {

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    fun createInquiry(
        @Login(required = false) loginMember: LoginMember?,
        @RequestBody @Validated request: CreateInquiryRequest,
        servletRequest: HttpServletRequest,
    ): CreateInquiryResponse {
        return inquiryService.createInquiry(
            memberId = loginMember?.id,
            request = request,
            ipAddress = servletRequest.remoteAddr,
        )
    }
}
