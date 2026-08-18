package com.tistory.shanepark.dutypark.inquiry.domain.dto

import com.tistory.shanepark.dutypark.inquiry.domain.entity.Inquiry
import com.tistory.shanepark.dutypark.inquiry.domain.enums.InquiryStatus
import jakarta.validation.constraints.NotNull
import jakarta.validation.constraints.Size
import java.time.LocalDateTime
import java.util.UUID

data class AdminInquiryDto(
    val id: UUID,
    val memberId: Long?,
    val memberName: String?,
    val email: String,
    val subject: String?,
    val content: String,
    val status: InquiryStatus,
    val adminMemo: String?,
    val createdAt: LocalDateTime,
    val closedAt: LocalDateTime?,
) {
    companion object {
        fun of(inquiry: Inquiry): AdminInquiryDto {
            return AdminInquiryDto(
                id = inquiry.id,
                memberId = inquiry.member?.id,
                memberName = inquiry.member?.name,
                email = inquiry.email,
                subject = inquiry.subject,
                content = inquiry.content,
                status = inquiry.status,
                adminMemo = inquiry.adminMemo,
                createdAt = inquiry.createdDate,
                closedAt = inquiry.closedAt,
            )
        }
    }
}

data class UpdateInquiryStatusRequest(
    @field:NotNull val status: InquiryStatus,
    @field:Size(max = 1000) val memo: String? = null,
)
