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
    val answer: String?,
    val answeredAt: LocalDateTime?,
    val answeredBy: Long?,
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
                answer = inquiry.answer,
                answeredAt = inquiry.answeredAt,
                answeredBy = inquiry.answeredBy,
            )
        }
    }
}

data class UpdateInquiryStatusRequest(
    @field:NotNull val status: InquiryStatus,
    @field:Size(max = 1000) val memo: String? = null,
    // 사용자에게 그대로 공개된다. 공백만 있으면 무시하고 기존 답변을 유지한다.
    @field:Size(max = 2000) val answer: String? = null,
)
