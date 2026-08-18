package com.tistory.shanepark.dutypark.inquiry.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.RateLimitException
import com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification
import com.tistory.shanepark.dutypark.inquiry.config.InquiryRateLimitConfig
import com.tistory.shanepark.dutypark.inquiry.domain.dto.AdminInquiryDto
import com.tistory.shanepark.dutypark.inquiry.domain.dto.CreateInquiryRequest
import com.tistory.shanepark.dutypark.inquiry.domain.dto.CreateInquiryResponse
import com.tistory.shanepark.dutypark.inquiry.domain.dto.UpdateInquiryStatusRequest
import com.tistory.shanepark.dutypark.inquiry.domain.entity.Inquiry
import com.tistory.shanepark.dutypark.inquiry.domain.enums.InquiryStatus
import com.tistory.shanepark.dutypark.inquiry.repository.InquiryRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.LocalDateTime
import java.time.ZoneId
import java.util.UUID

@Service
@Transactional(readOnly = true)
class InquiryService(
    private val inquiryRepository: InquiryRepository,
    private val memberRepository: MemberRepository,
    private val rateLimitConfig: InquiryRateLimitConfig,
    private val clock: Clock,
) {
    private val log = logger()

    @Transactional
    @SlackNotification
    fun createInquiry(memberId: Long?, request: CreateInquiryRequest, ipAddress: String): CreateInquiryResponse {
        val now = now()
        val recentCount = inquiryRepository.countByIpAddressAndCreatedDateAfter(
            ipAddress = ipAddress,
            createdDate = now.minusMinutes(RATE_LIMIT_WINDOW_MINUTES),
        )
        if (recentCount >= rateLimitConfig.maxPerHour) {
            log.warn("Inquiry rate limit exceeded. ip={}, recentCount={}", ipAddress, recentCount)
            throw RateLimitException("inquiry.rateLimit.exceeded")
        }

        val member = memberId?.let {
            memberRepository.findById(it).orElseThrow { NoSuchElementException("inquiry.member.notFound") }
        }
        val inquiry = inquiryRepository.save(
            Inquiry(
                member = member,
                email = request.email,
                subject = request.subject,
                content = request.content,
                ipAddress = ipAddress,
            )
        )
        return CreateInquiryResponse(id = inquiry.id)
    }

    fun findInquiries(status: InquiryStatus?, pageable: Pageable): Page<AdminInquiryDto> {
        val inquiries = status?.let { inquiryRepository.findAllByStatusOrderByCreatedDateDesc(it, pageable) }
            ?: inquiryRepository.findAllByOrderByCreatedDateDesc(pageable)
        return inquiries.map(AdminInquiryDto::of)
    }

    fun findInquiry(id: UUID): AdminInquiryDto {
        return AdminInquiryDto.of(findInquiryOrThrow(id))
    }

    @Transactional
    fun changeStatus(id: UUID, request: UpdateInquiryStatusRequest, adminId: Long): AdminInquiryDto {
        val inquiry = findInquiryOrThrow(id)
        inquiry.changeStatus(status = request.status, memo = request.memo, adminId = adminId, now = now())
        return AdminInquiryDto.of(inquiry)
    }

    private fun findInquiryOrThrow(id: UUID): Inquiry =
        inquiryRepository.findById(id).orElseThrow { NoSuchElementException("inquiry.notFound") }

    /**
     * created_date 는 JPA Auditing 이 JVM 기본 시간대로 기록하므로 시간 창 계산도 같은 시간대에서 해야 한다.
     */
    private fun now(): LocalDateTime = LocalDateTime.now(clock.withZone(ZoneId.systemDefault()))

    companion object {
        private const val RATE_LIMIT_WINDOW_MINUTES = 60L
    }
}
