package com.tistory.shanepark.dutypark.inquiry.service

import com.tistory.shanepark.dutypark.common.exceptions.RateLimitException
import com.tistory.shanepark.dutypark.inquiry.config.InquiryRateLimitConfig
import com.tistory.shanepark.dutypark.inquiry.domain.dto.CreateInquiryRequest
import com.tistory.shanepark.dutypark.inquiry.domain.entity.Inquiry
import com.tistory.shanepark.dutypark.inquiry.domain.entity.InquiryRateLimitLock
import com.tistory.shanepark.dutypark.inquiry.repository.InquiryRateLimitLockRepository
import com.tistory.shanepark.dutypark.inquiry.repository.InquiryRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import jakarta.persistence.LockModeType
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import org.mockito.kotlin.any
import org.mockito.kotlin.mock
import org.mockito.kotlin.never
import org.mockito.kotlin.verify
import org.mockito.kotlin.verifyNoInteractions
import org.mockito.kotlin.whenever
import org.springframework.context.ApplicationEventPublisher
import org.springframework.data.jpa.repository.Lock
import java.time.Clock
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.util.Optional

class InquiryRateLimitServiceTest {

    private val inquiryRepository: InquiryRepository = mock()
    private val lockRepository: InquiryRateLimitLockRepository = mock()
    private val memberRepository: MemberRepository = mock()
    private val clock = Clock.fixed(Instant.parse("2026-08-18T01:00:00Z"), ZoneId.of("UTC"))
    private val service = InquiryService(
        inquiryRepository = inquiryRepository,
        rateLimitLockRepository = lockRepository,
        memberRepository = memberRepository,
        rateLimitConfig = InquiryRateLimitConfig(maxPerHour = 5),
        clock = clock,
        eventPublisher = mock<ApplicationEventPublisher>(),
        slackNotifier = mock<InquirySlackNotifier>(),
    )

    @Test
    fun `create inquiry locks only its rate limit bucket and uses an exclusive one hour cutoff`() {
        whenever(lockRepository.findByIdForUpdate(any())).thenReturn(Optional.of(InquiryRateLimitLock(0)))
        whenever(inquiryRepository.countByIpAddressAndCreatedDateAfter(any(), any())).thenReturn(4)
        whenever(inquiryRepository.save(any<Inquiry>())).thenAnswer { it.arguments[0] as Inquiry }

        service.createInquiry(memberId = null, request = request(), ipAddress = "198.51.100.10")

        val cutoff = LocalDateTime.now(clock.withZone(ZoneId.systemDefault())).minusMinutes(60)
        verify(lockRepository).findByIdForUpdate(any())
        verify(inquiryRepository).countByIpAddressAndCreatedDateAfter("198.51.100.10", cutoff)
        verify(inquiryRepository).save(any<Inquiry>())
    }

    @Test
    fun `full quota rejects without loading a member or storing an inquiry`() {
        whenever(lockRepository.findByIdForUpdate(any())).thenReturn(Optional.of(InquiryRateLimitLock(0)))
        whenever(inquiryRepository.countByIpAddressAndCreatedDateAfter(any(), any())).thenReturn(5)

        assertThatThrownBy {
            service.createInquiry(memberId = null, request = request(), ipAddress = "198.51.100.11")
        }.isInstanceOf(RateLimitException::class.java)

        verify(inquiryRepository, never()).save(any<Inquiry>())
        verifyNoInteractions(memberRepository)
    }

    @Test
    fun `rate limit bucket lookup declares a pessimistic write lock`() {
        val method = InquiryRateLimitLockRepository::class.java.getMethod("findByIdForUpdate", Int::class.java)

        assertThat(method.getAnnotation(Lock::class.java).value).isEqualTo(LockModeType.PESSIMISTIC_WRITE)
    }

    private fun request() = CreateInquiryRequest(
        email = "guest@dutypark.o-r.kr",
        subject = null,
        content = "문의 내용",
    )
}
