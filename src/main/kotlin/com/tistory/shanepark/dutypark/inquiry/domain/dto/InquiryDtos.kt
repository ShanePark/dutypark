package com.tistory.shanepark.dutypark.inquiry.domain.dto

import com.tistory.shanepark.dutypark.inquiry.domain.entity.Inquiry
import com.tistory.shanepark.dutypark.inquiry.domain.enums.InquiryStatus
import jakarta.validation.constraints.Email
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import java.time.LocalDateTime
import java.util.UUID

data class CreateInquiryRequest(
    @field:NotBlank @field:Email @field:Size(max = 255) val email: String,
    @field:Size(max = 100) val subject: String? = null,
    @field:NotBlank @field:Size(max = 2000) val content: String,
)

data class CreateInquiryResponse(
    val id: UUID,
)

/**
 * 사용자에게 노출되는 문의 DTO. 내부 정보(adminMemo, ipAddress, closedBy, answeredBy)는 절대 담지 않는다.
 */
data class MyInquiryDto(
    val id: UUID,
    val email: String,
    val subject: String?,
    val content: String,
    val status: InquiryStatus,
    val createdAt: LocalDateTime,
    val answer: String?,
    val answeredAt: LocalDateTime?,
) {
    companion object {
        fun of(inquiry: Inquiry): MyInquiryDto {
            return MyInquiryDto(
                id = inquiry.id,
                email = inquiry.email,
                subject = inquiry.subject,
                content = inquiry.content,
                status = inquiry.status,
                createdAt = inquiry.createdDate,
                answer = inquiry.answer,
                answeredAt = inquiry.answeredAt,
            )
        }
    }
}
