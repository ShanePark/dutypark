package com.tistory.shanepark.dutypark.inquiry.service

import ch.qos.logback.classic.Logger
import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.core.read.ListAppender
import com.tistory.shanepark.dutypark.inquiry.config.InquiryRateLimitConfig
import com.tistory.shanepark.dutypark.inquiry.domain.dto.CreateInquiryRequest
import com.tistory.shanepark.dutypark.inquiry.domain.dto.UpdateInquiryStatusRequest
import com.tistory.shanepark.dutypark.inquiry.domain.entity.Inquiry
import com.tistory.shanepark.dutypark.inquiry.domain.entity.InquiryRateLimitLock
import com.tistory.shanepark.dutypark.inquiry.domain.enums.InquiryStatus
import com.tistory.shanepark.dutypark.inquiry.repository.InquiryRateLimitLockRepository
import com.tistory.shanepark.dutypark.inquiry.repository.InquiryRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.notification.event.InquiryAnsweredEvent
import jakarta.persistence.LockModeType
import java.time.Clock
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.util.Optional
import java.util.UUID
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.kotlin.any
import org.mockito.kotlin.mock
import org.mockito.kotlin.never
import org.mockito.kotlin.times
import org.mockito.kotlin.verify
import org.mockito.kotlin.verifyNoInteractions
import org.mockito.kotlin.whenever
import org.slf4j.LoggerFactory
import org.springframework.context.ApplicationEventPublisher
import org.springframework.data.jpa.repository.Lock
import org.springframework.test.util.ReflectionTestUtils

class InquiryServiceTest {

    private val inquiryRepository: InquiryRepository = mock()
    private val rateLimitLockRepository: InquiryRateLimitLockRepository = mock()
    private val memberRepository: MemberRepository = mock()
    private val eventPublisher: ApplicationEventPublisher = mock()
    private val clock: Clock = Clock.fixed(Instant.parse("2026-08-18T01:00:00Z"), ZoneId.of("UTC"))

    private val inquiryService = InquiryService(
        inquiryRepository = inquiryRepository,
        rateLimitLockRepository = rateLimitLockRepository,
        memberRepository = memberRepository,
        rateLimitConfig = InquiryRateLimitConfig(maxPerHour = 5),
        clock = clock,
        eventPublisher = eventPublisher,
        slackNotifier = mock<InquirySlackNotifier>(),
    )

    private val adminId = 99L

    @Test
    fun `guest inquiry submission audit excludes email subject content and IP`() {
        whenever(rateLimitLockRepository.findByIdForUpdate(any())).thenReturn(Optional.of(
            InquiryRateLimitLock(0)
        ))
        whenever(inquiryRepository.save(org.mockito.kotlin.any<Inquiry>())).thenAnswer { it.getArgument<Inquiry>(0) }
        val logger = LoggerFactory.getLogger(InquiryService::class.java) as Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try {
            val result = inquiryService.createInquiry(null,
                CreateInquiryRequest(
                    email = "private@example.test", subject = "private subject", content = "private content",
                ), "192.0.2.10")
            assertThat(appender.list).hasSize(1)
            assertThat(appender.list.single().formattedMessage).contains("inquiry.created", result.id.toString(), "\"actor\":null")
                .doesNotContain("private@example.test", "private subject", "private content", "192.0.2.10")
        } finally {
            logger.detachAppender(appender)
        }
    }

    @Test
    fun `inquiry response audit records changes without private text and omits unchanged response`() {
        val inquiry = inquiry(member = null, subject = "private subject")
        whenever(inquiryRepository.findByIdForUpdate(inquiry.id)).thenReturn(Optional.of(inquiry))
        val logger = LoggerFactory.getLogger(InquiryService::class.java) as Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try {
            val request = UpdateInquiryStatusRequest(status = InquiryStatus.CLOSED, memo = "private memo", answer = "private answer")
            inquiryService.changeStatus(inquiry.id, request, adminId)
            inquiryService.changeStatus(inquiry.id, request, adminId)
            val messages = appender.list.map { it.formattedMessage }
            assertThat(messages).hasSize(1)
            assertThat(messages.single()).contains("inquiry.updated", inquiry.id.toString(), "\"id\":99", "OPEN", "CLOSED", "answerChanged")
                .doesNotContain("private subject", "private memo", "private answer", "tester@dutypark.o-r.kr", "문의 내용")
        } finally {
            logger.detachAppender(appender)
        }
    }

    @Test
    fun `first answer publishes inquiry answered event only once`() {
        val member = memberWithId(1L)
        val inquiry = inquiry(member = member, subject = "일정이 보이지 않습니다")
        whenever(inquiryRepository.findByIdForUpdate(inquiry.id)).thenReturn(Optional.of(inquiry))

        inquiryService.changeStatus(
            id = inquiry.id,
            request = UpdateInquiryStatusRequest(status = InquiryStatus.CLOSED, answer = "확인 후 처리했습니다."),
            adminId = adminId,
        )

        verify(eventPublisher).publishEvent(
            InquiryAnsweredEvent(
                inquiryId = inquiry.id,
                memberId = member.id!!,
                subject = "일정이 보이지 않습니다",
            )
        )

        inquiryService.changeStatus(
            id = inquiry.id,
            request = UpdateInquiryStatusRequest(status = InquiryStatus.CLOSED, answer = "오타를 고친 답변입니다."),
            adminId = adminId,
        )

        verify(eventPublisher, times(1)).publishEvent(any<InquiryAnsweredEvent>())
        assertThat(inquiry.answer).isEqualTo("오타를 고친 답변입니다.")
        assertThat(inquiry.answeredBy).isEqualTo(adminId)
    }

    @Test
    fun `guest inquiry answer is stored without publishing an event`() {
        val inquiry = inquiry(member = null, subject = "비회원 문의")
        whenever(inquiryRepository.findByIdForUpdate(inquiry.id)).thenReturn(Optional.of(inquiry))

        inquiryService.changeStatus(
            id = inquiry.id,
            request = UpdateInquiryStatusRequest(status = InquiryStatus.CLOSED, answer = "메일로 회신했습니다."),
            adminId = adminId,
        )

        assertThat(inquiry.answer).isEqualTo("메일로 회신했습니다.")
        verifyNoInteractions(eventPublisher)
    }

    @Test
    fun `blank answer keeps the existing answer and publishes nothing`() {
        val member = memberWithId(1L)
        val inquiry = inquiry(member = member, subject = "이미 답변한 문의")
        inquiry.writeAnswer("기존 답변입니다.", adminId, clock.instant().atZone(ZoneId.systemDefault()).toLocalDateTime())
        whenever(inquiryRepository.findByIdForUpdate(inquiry.id)).thenReturn(Optional.of(inquiry))

        inquiryService.changeStatus(
            id = inquiry.id,
            request = UpdateInquiryStatusRequest(status = InquiryStatus.OPEN, answer = "   "),
            adminId = adminId,
        )

        assertThat(inquiry.answer).isEqualTo("기존 답변입니다.")
        verify(eventPublisher, never()).publishEvent(any<InquiryAnsweredEvent>())
    }

    @Test
    fun `missing answer field does not touch the answer`() {
        val member = memberWithId(1L)
        val inquiry = inquiry(member = member, subject = "메모만 수정")
        whenever(inquiryRepository.findByIdForUpdate(inquiry.id)).thenReturn(Optional.of(inquiry))

        inquiryService.changeStatus(
            id = inquiry.id,
            request = UpdateInquiryStatusRequest(status = InquiryStatus.CLOSED, memo = "내부 메모"),
            adminId = adminId,
        )

        assertThat(inquiry.answer).isNull()
        assertThat(inquiry.answeredAt).isNull()
        assertThat(inquiry.answeredBy).isNull()
        verifyNoInteractions(eventPublisher)
    }

    @Test
    fun `updating a closed inquiry keeps the original closer and closed time`() {
        val originalClosedAt = LocalDateTime.of(2026, 8, 17, 9, 30)
        val originalAdminId = 42L
        val inquiry = inquiry(member = null, subject = "종료 정보 보존")
        inquiry.changeStatus(InquiryStatus.CLOSED, "최초 메모", originalAdminId, originalClosedAt)
        whenever(inquiryRepository.findByIdForUpdate(inquiry.id)).thenReturn(Optional.of(inquiry))

        inquiryService.changeStatus(
            id = inquiry.id,
            request = UpdateInquiryStatusRequest(
                status = InquiryStatus.CLOSED,
                memo = "수정한 메모",
                answer = "추가 답변",
            ),
            adminId = adminId,
        )

        assertThat(inquiry.adminMemo).isEqualTo("수정한 메모")
        assertThat(inquiry.answer).isEqualTo("추가 답변")
        assertThat(inquiry.closedAt).isEqualTo(originalClosedAt)
        assertThat(inquiry.closedBy).isEqualTo(originalAdminId)
    }

    @Test
    fun `change status loads the inquiry with a pessimistic write lock`() {
        val inquiry = inquiry(member = null, subject = "잠금 확인")
        whenever(inquiryRepository.findByIdForUpdate(inquiry.id)).thenReturn(Optional.of(inquiry))

        inquiryService.changeStatus(
            id = inquiry.id,
            request = UpdateInquiryStatusRequest(status = InquiryStatus.CLOSED),
            adminId = adminId,
        )

        verify(inquiryRepository).findByIdForUpdate(inquiry.id)
        verify(inquiryRepository, never()).findById(inquiry.id)
    }

    @Test
    fun `inquiry update lookup declares a pessimistic write lock`() {
        val method = InquiryRepository::class.java.getMethod("findByIdForUpdate", UUID::class.java)

        assertThat(method.getAnnotation(Lock::class.java).value).isEqualTo(LockModeType.PESSIMISTIC_WRITE)
    }

    @Test
    fun `plain inquiry detail lookup does not use the update lock`() {
        val inquiry = inquiry(member = null, subject = "일반 조회")
        whenever(inquiryRepository.findById(inquiry.id)).thenReturn(Optional.of(inquiry))

        inquiryService.findInquiry(inquiry.id)

        verify(inquiryRepository).findById(inquiry.id)
        verify(inquiryRepository, never()).findByIdForUpdate(inquiry.id)
    }

    private fun inquiry(member: Member?, subject: String?): Inquiry {
        return Inquiry(
            member = member,
            email = "tester@dutypark.o-r.kr",
            subject = subject,
            content = "문의 내용",
            ipAddress = "127.0.0.1",
        )
    }

    private fun memberWithId(id: Long): Member {
        val member = Member(name = "tester", email = "tester@duty.park", password = "password")
        ReflectionTestUtils.setField(member, "id", id)
        return member
    }
}
