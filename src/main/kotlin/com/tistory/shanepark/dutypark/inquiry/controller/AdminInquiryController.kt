package com.tistory.shanepark.dutypark.inquiry.controller

import com.tistory.shanepark.dutypark.common.domain.dto.PageResponse
import com.tistory.shanepark.dutypark.inquiry.domain.dto.AdminInquiryDto
import com.tistory.shanepark.dutypark.inquiry.domain.dto.UpdateInquiryStatusRequest
import com.tistory.shanepark.dutypark.inquiry.domain.enums.InquiryStatus
import com.tistory.shanepark.dutypark.inquiry.service.InquiryService
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.data.domain.Pageable
import org.springframework.data.web.PageableDefault
import org.springframework.validation.annotation.Validated
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PatchMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/admin/api/inquiries")
class AdminInquiryController(
    private val inquiryService: InquiryService,
) {

    @GetMapping
    fun findInquiries(
        @RequestParam(required = false) status: String?,
        @PageableDefault(size = 10) pageable: Pageable,
    ): PageResponse<AdminInquiryDto> {
        return PageResponse(inquiryService.findInquiries(parseStatus(status), pageable))
    }

    @GetMapping("/{id}")
    fun findInquiry(
        @PathVariable id: UUID,
    ): AdminInquiryDto {
        return inquiryService.findInquiry(id)
    }

    @PatchMapping("/{id}/status")
    fun changeStatus(
        @Login loginMember: LoginMember,
        @PathVariable id: UUID,
        @RequestBody @Validated request: UpdateInquiryStatusRequest,
    ): AdminInquiryDto {
        return inquiryService.changeStatus(id = id, request = request, adminId = loginMember.id)
    }

    private fun parseStatus(status: String?): InquiryStatus? {
        val value = status?.trim().orEmpty()
        if (value.isEmpty() || value.equals(ALL_STATUS, ignoreCase = true)) {
            return null
        }
        return InquiryStatus.valueOf(value.uppercase())
    }

    companion object {
        private const val ALL_STATUS = "ALL"
    }
}
