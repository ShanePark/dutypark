package com.tistory.shanepark.dutypark.inquiry.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.BadRequestException
import com.tistory.shanepark.dutypark.common.exceptions.RateLimitException
import com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification
import com.tistory.shanepark.dutypark.inquiry.config.InquiryRateLimitConfig
import com.tistory.shanepark.dutypark.inquiry.domain.dto.AdminInquiryDto
import com.tistory.shanepark.dutypark.inquiry.domain.dto.CreateInquiryRequest
import com.tistory.shanepark.dutypark.inquiry.domain.dto.CreateInquiryResponse
import com.tistory.shanepark.dutypark.inquiry.domain.dto.MyInquiryDto
import com.tistory.shanepark.dutypark.inquiry.domain.dto.UpdateInquiryStatusRequest
import com.tistory.shanepark.dutypark.inquiry.domain.entity.Inquiry
import com.tistory.shanepark.dutypark.inquiry.domain.entity.InquiryRateLimitLock
import com.tistory.shanepark.dutypark.inquiry.domain.enums.InquiryStatus
import com.tistory.shanepark.dutypark.inquiry.repository.InquiryRateLimitLockRepository
import com.tistory.shanepark.dutypark.inquiry.repository.InquiryRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.notification.event.InquiryAnsweredEvent
import org.springframework.context.ApplicationEventPublisher
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
    private val rateLimitLockRepository: InquiryRateLimitLockRepository,
    private val memberRepository: MemberRepository,
    private val rateLimitConfig: InquiryRateLimitConfig,
    private val clock: Clock,
    private val eventPublisher: ApplicationEventPublisher,
) {
    private val log = logger()

    @Transactional
    @SlackNotification(includeArguments = false)
    fun createInquiry(memberId: Long?, request: CreateInquiryRequest, ipAddress: String): CreateInquiryResponse {
        lockRateLimitBucket(ipAddress)
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
                email = resolveEmail(request, member),
                subject = request.subject,
                content = request.content,
                ipAddress = ipAddress,
            )
        )
        return CreateInquiryResponse(id = inquiry.id)
    }

    /**
     * 회원 문의의 답변은 앱 안에서 읽으므로 회신 주소를 묻지 않는다. 계정 이메일이 있으면 기록해 두고,
     * 소셜 계정처럼 이메일이 없으면 비워 둔다. 비회원 문의는 답변을 보낼 곳이 이메일뿐이라 필수다.
     */
    private fun resolveEmail(request: CreateInquiryRequest, member: Member?): String? {
        val requested = request.email?.trim()?.takeIf(String::isNotEmpty)
        if (member != null) {
            return requested ?: member.email
        }
        return requested ?: throw BadRequestException("inquiry.email.required")
    }

    private fun lockRateLimitBucket(ipAddress: String) {
        val bucketId = Math.floorMod(ipAddress.hashCode(), RATE_LIMIT_LOCK_BUCKETS)
        if (rateLimitLockRepository.findByIdForUpdate(bucketId).isPresent) {
            return
        }

        // 운영 DB에는 migration 이 모든 버킷을 미리 만든다. create-drop 을 쓰는 테스트 DB도
        // 실제 잠금 경로를 사용할 수 있도록 누락된 행만 지연 생성한다.
        rateLimitLockRepository.saveAndFlush(InquiryRateLimitLock(bucketId))
    }

    fun findMyInquiries(memberId: Long, pageable: Pageable): Page<MyInquiryDto> {
        return inquiryRepository.findAllByMemberIdOrderByCreatedDateDesc(memberId, pageable).map(MyInquiryDto::of)
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
        val inquiry = findInquiryForUpdateOrThrow(id)
        val now = now()
        inquiry.changeStatus(status = request.status, memo = request.memo, adminId = adminId, now = now)
        writeAnswerIfPresent(inquiry = inquiry, answer = request.answer, adminId = adminId, now = now)
        return AdminInquiryDto.of(inquiry)
    }

    /**
     * 답변이 비어 있으면 기존 답변을 유지한다. 최초 답변일 때만 회원에게 알림을 보낸다.
     */
    private fun writeAnswerIfPresent(inquiry: Inquiry, answer: String?, adminId: Long, now: LocalDateTime) {
        val trimmedAnswer = answer?.trim()?.takeIf(String::isNotEmpty) ?: return
        val firstAnswer = inquiry.writeAnswer(answer = trimmedAnswer, adminId = adminId, now = now)
        val memberId = inquiry.member?.id
        if (firstAnswer && memberId != null) {
            eventPublisher.publishEvent(
                InquiryAnsweredEvent(inquiryId = inquiry.id, memberId = memberId, subject = inquiry.subject)
            )
        }
    }

    private fun findInquiryOrThrow(id: UUID): Inquiry =
        inquiryRepository.findById(id).orElseThrow { NoSuchElementException("inquiry.notFound") }

    private fun findInquiryForUpdateOrThrow(id: UUID): Inquiry =
        inquiryRepository.findByIdForUpdate(id).orElseThrow { NoSuchElementException("inquiry.notFound") }

    /**
     * created_date 는 JPA Auditing 이 JVM 기본 시간대로 기록하므로 시간 창 계산도 같은 시간대에서 해야 한다.
     */
    private fun now(): LocalDateTime = LocalDateTime.now(clock.withZone(ZoneId.systemDefault()))

    companion object {
        private const val RATE_LIMIT_WINDOW_MINUTES = 60L
        private const val RATE_LIMIT_LOCK_BUCKETS = 256
    }
}
