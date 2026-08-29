package com.tistory.shanepark.dutypark.common.slack

import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.core.read.ListAppender
import com.google.gson.JsonObject
import com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification
import com.tistory.shanepark.dutypark.common.slack.aspect.SlackNotificationAspect
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackEventNotifier
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackNotifier
import com.tistory.shanepark.dutypark.inquiry.domain.dto.CreateInquiryRequest
import com.tistory.shanepark.dutypark.inquiry.domain.entity.Inquiry
import com.tistory.shanepark.dutypark.inquiry.service.InquirySlackNotifier
import com.tistory.shanepark.dutypark.inquiry.service.InquiryService
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.report.domain.dto.CreateReportRequest
import com.tistory.shanepark.dutypark.report.domain.dto.ReportCreateResult
import com.tistory.shanepark.dutypark.report.domain.entity.ContentReport
import com.tistory.shanepark.dutypark.report.domain.enums.ReportReason
import com.tistory.shanepark.dutypark.report.domain.enums.ReportTargetType
import com.tistory.shanepark.dutypark.report.service.ReportService
import com.tistory.shanepark.dutypark.report.service.ReportSlackNotifier
import net.gpedro.integrations.slack.SlackMessage
import net.gpedro.integrations.slack.SlackException
import org.aspectj.lang.ProceedingJoinPoint
import org.aspectj.lang.reflect.MethodSignature
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.kotlin.any
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.verifyNoInteractions
import org.mockito.kotlin.whenever
import org.slf4j.LoggerFactory
import org.springframework.core.task.SyncTaskExecutor
import org.springframework.test.util.ReflectionTestUtils
import java.util.UUID

class SlackSubmissionPrivacyTest {

    private val notifier: SlackNotifier = mock()
    private val eventNotifier = SlackEventNotifier(notifier, SyncTaskExecutor())

    @Test
    fun `submission entry points do not fall back to the generic argument dump`() {
        val createInquiry = InquiryService::class.java.getMethod(
            "createInquiry",
            Long::class.javaObjectType,
            CreateInquiryRequest::class.java,
            String::class.java,
        )
        val createReport = ReportService::class.java.getMethod(
            "createReport",
            Long::class.javaPrimitiveType!!,
            CreateReportRequest::class.java,
        )

        // 전용 알림이 필요한 값만 골라 보낸다. @SlackNotification 을 다시 붙이면 알림이 중복되고
        // 이메일·본문·IP 가 가공 없이 슬랙으로 나간다.
        assertThat(createInquiry.getAnnotation(SlackNotification::class.java)).isNull()
        assertThat(createReport.getAnnotation(SlackNotification::class.java)).isNull()
    }

    @Test
    fun `message body is not repeated above the attachment`() {
        InquirySlackNotifier(eventNotifier).inquiryCreated(inquiry(subject = "제목", content = "내용"))

        // 첨부 밖 본문까지 채우면 같은 문구가 두 번 나오면서 메시지만 길어진다.
        assertThat(captured()["text"].asString).isEmpty()
    }

    @Test
    fun `inquiry notification contains only the event and account kind`() {
        val inquiry = Inquiry(
            member = memberWithId(id = 42L, name = "홍길동"),
            email = "private@example.com",
            subject = "일정이 보이지 않습니다",
            content = "8월 일정이 사라졌어요",
            ipAddress = "192.0.2.1",
        )

        InquirySlackNotifier(eventNotifier).inquiryCreated(inquiry)

        val attachment = capturedAttachment()
        assertThat(attachment["title"].asString).isEqualTo("📩 New inquiry")
        assertThat(attachment["text"].asString).isEqualTo("`MEMBER`")
        assertThat(attachment["footer"]).isNull()
        assertThat(attachment["color"].asString).isEqualTo(SlackEventLevel.INFO.color)
        assertThat(captured().toString()).doesNotContain(
            "홍길동",
            "42",
            "private@example.com",
            "192.0.2.1",
            "일정이 보이지 않습니다",
            "8월 일정이 사라졌어요",
            inquiry.id.toString(),
        )
    }

    @Test
    fun `guest inquiry contains no submitted values`() {
        val inquiry = Inquiry(
            member = null,
            email = "g@example.com",
            subject = null,
            content = "비회원 문의입니다",
            ipAddress = "2001:db8:85a3::8a2e:370:7334",
        )

        InquirySlackNotifier(eventNotifier).inquiryCreated(inquiry)

        val attachment = capturedAttachment()
        assertThat(attachment["title"].asString).isEqualTo("📩 New inquiry")
        assertThat(attachment["text"].asString).isEqualTo("`GUEST`")
        assertThat(attachment["footer"]).isNull()
        assertThat(captured().toString()).doesNotContain(
            "g@example.com",
            "2001:db8:85a3::8a2e:370:7334",
            "비회원 문의입니다",
            inquiry.id.toString(),
        )
    }

    @Test
    fun `long inquiry content is omitted rather than previewed`() {
        val content = "가".repeat(400)
        InquirySlackNotifier(eventNotifier).inquiryCreated(inquiry(subject = null, content = content))

        assertThat(capturedAttachment()["text"].asString).isEqualTo("`GUEST`")
        assertThat(captured().toString()).doesNotContain(content)
    }

    @Test
    fun `multi line inquiry content is omitted`() {
        val content = "첫 줄\n둘째 줄"
        InquirySlackNotifier(eventNotifier).inquiryCreated(inquiry(subject = null, content = content))

        assertThat(capturedAttachment()["text"].asString).isEqualTo("`GUEST`")
        assertThat(captured().toString()).doesNotContain(content)
    }

    @Test
    fun `report notification contains only moderation enums`() {
        val reportId = UUID.randomUUID()

        ReportSlackNotifier(eventNotifier).reportCreated(
            result = ReportCreateResult(id = reportId, isNew = true),
            reporter = memberWithId(id = 7L, name = "신고자"),
            reported = memberWithId(id = 9L, name = "피신고자"),
            request = CreateReportRequest(
                targetType = ReportTargetType.SCHEDULE,
                targetId = "9b7f1f0e-0000-0000-0000-000000000001",
                reason = ReportReason.HARASSMENT,
                detail = "욕설이 포함되어 있습니다",
                alsoBlock = true,
            ),
        )

        val attachment = capturedAttachment()
        assertThat(attachment["title"].asString).isEqualTo("🚨 New report")
        assertThat(attachment["text"].asString).isEqualTo(
            """
            *HARASSMENT*
            `SCHEDULE`  `also blocked`
            """.trimIndent()
        )
        assertThat(attachment["footer"]).isNull()
        assertThat(attachment["color"].asString).isEqualTo(SlackEventLevel.NOTICE.color)
        assertThat(captured().toString()).doesNotContain(
            "신고자",
            "피신고자",
            reportId.toString(),
            "9b7f1f0e-0000-0000-0000-000000000001",
            "욕설이 포함되어 있습니다",
        )
    }

    @Test
    fun `duplicate report is dimmed and flagged so it is not triaged twice`() {
        ReportSlackNotifier(eventNotifier).reportCreated(
            result = ReportCreateResult(id = UUID.randomUUID(), isNew = false),
            reporter = memberWithId(id = 7L, name = "신고자"),
            reported = memberWithId(id = 9L, name = "피신고자"),
            request = CreateReportRequest(
                targetType = ReportTargetType.MEMBER,
                targetId = "9",
                reason = ReportReason.OTHER,
                detail = null,
                alsoBlock = false,
            ),
        )

        val attachment = capturedAttachment()
        assertThat(attachment["text"].asString).isEqualTo(
            """
            *OTHER*
            `MEMBER`  `duplicate`
            """.trimIndent()
        )
        assertThat(attachment["footer"]).isNull()
        assertThat(attachment["color"].asString).isEqualTo(SlackEventLevel.MUTED.color)
        assertThat(captured().toString()).doesNotContain("신고자", "피신고자", "욕설이 포함되어 있습니다")
    }

    @Test
    fun `canceled report contains only moderation enums`() {
        val report = report(reported = memberWithId(id = 9L, name = "피신고자"))

        ReportSlackNotifier(eventNotifier).reportCanceled(report)

        val attachment = capturedAttachment()
        assertThat(attachment["title"].asString).isEqualTo("↩️ Report canceled")
        assertThat(attachment["text"].asString).isEqualTo(
            """
            *HARASSMENT*
            `SCHEDULE`
            """.trimIndent()
        )
        assertThat(attachment["footer"]).isNull()
        assertThat(attachment["color"].asString).isEqualTo(SlackEventLevel.MUTED.color)
        assertThat(captured().toString()).doesNotContain(
            "신고자",
            "피신고자",
            report.id.toString(),
            "9b7f1f0e-0000-0000-0000-000000000001",
            "욕설이 포함되어 있습니다",
            "제목: 회식",
        )
    }

    @Test
    fun `canceled report of a deleted account still contains no names`() {
        ReportSlackNotifier(eventNotifier).reportCanceled(report(reported = null))

        assertThat(capturedAttachment()["title"].asString)
            .isEqualTo("↩️ Report canceled")
        assertThat(captured().toString()).doesNotContain("신고자", "피신고자")
    }

    @Test
    fun `generic aspect never includes arguments even when annotation allows them`() {
        val joinPoint = mock<ProceedingJoinPoint>()
        val signature = mock<MethodSignature>()
        val method = AnnotatedOperation::class.java.getDeclaredMethod(
            "save",
            String::class.java,
            String::class.java,
        )
        whenever(joinPoint.proceed()).thenReturn("result")
        whenever(joinPoint.signature).thenReturn(signature)
        whenever(signature.method).thenReturn(method)
        whenever(signature.name).thenReturn("save")
        whenever(joinPoint.args).thenReturn(
            arrayOf<Any?>("private@example.com", "submitted text and 192.0.2.1")
        )

        val result = SlackNotificationAspect(notifier, SyncTaskExecutor()).slackNotification(joinPoint)

        assertThat(result).isEqualTo("result")
        val attachment = capturedAttachment()
        assertThat(attachment["title"].asString).isEqualTo("Data save detected")
        assertThat(attachment["fields"].asJsonArray.map { it.asJsonObject["title"].asString })
            .containsExactly("method")
        assertThat(attachment["fields"].asJsonArray.single().asJsonObject["value"].asString)
            .isEqualTo("save")
        assertThat(captured().toString()).doesNotContain(
            "private@example.com",
            "submitted text",
            "192.0.2.1",
        )
    }

    @Test
    fun `generic aspect does not log exception message or stack trace`() {
        val joinPoint = mock<ProceedingJoinPoint>()
        val signature = mock<MethodSignature>()
        val secret = "submitted secret from request"
        whenever(joinPoint.signature).thenReturn(signature)
        whenever(signature.name).thenReturn("save")
        whenever(joinPoint.proceed()).thenThrow(IllegalStateException(secret))

        val logger = LoggerFactory.getLogger(SlackNotificationAspect::class.java)
            as ch.qos.logback.classic.Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try {
            org.junit.jupiter.api.assertThrows<IllegalStateException> {
                SlackNotificationAspect(notifier, SyncTaskExecutor()).slackNotification(joinPoint)
            }
        } finally {
            logger.detachAppender(appender)
        }

        assertThat(appender.list).hasSize(1)
        assertThat(appender.list.single().formattedMessage).doesNotContain(secret)
        assertThat(appender.list.single().throwableProxy).isNull()
        verifyNoInteractions(notifier)
    }

    @Test
    fun `event notifier logs only the exception class when sending fails`() {
        val secret = "https://hooks.slack.com/services/T000/B000/secret-token"
        whenever(notifier.call(any())).thenThrow(SlackException(IllegalStateException(secret)))

        val logger = LoggerFactory.getLogger(SlackEventNotifier::class.java)
            as ch.qos.logback.classic.Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try {
            eventNotifier.send(SlackEvent(emoji = "🔔", title = "Test event"))
        } finally {
            logger.detachAppender(appender)
        }

        assertThat(appender.list).hasSize(1)
        assertThat(appender.list.single().formattedMessage)
            .contains("SlackException")
            .doesNotContain(secret)
        assertThat(appender.list.single().throwableProxy).isNull()
    }

    @Test
    fun `generic aspect logs only the exception class when async sending fails`() {
        val secret = "https://hooks.slack.com/services/T000/B000/secret-token"
        whenever(notifier.call(any())).thenThrow(SlackException(IllegalStateException(secret)))

        val joinPoint = mock<ProceedingJoinPoint>()
        val signature = mock<MethodSignature>()
        whenever(joinPoint.proceed()).thenReturn("result")
        whenever(joinPoint.signature).thenReturn(signature)
        whenever(signature.name).thenReturn("save")

        val logger = LoggerFactory.getLogger(SlackNotificationAspect::class.java)
            as ch.qos.logback.classic.Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try {
            assertThat(SlackNotificationAspect(notifier, SyncTaskExecutor()).slackNotification(joinPoint))
                .isEqualTo("result")
        } finally {
            logger.detachAppender(appender)
        }

        assertThat(appender.list).hasSize(1)
        assertThat(appender.list.single().formattedMessage)
            .contains("SlackException")
            .doesNotContain(secret)
        assertThat(appender.list.single().throwableProxy).isNull()
    }

    private class AnnotatedOperation {
        @SlackNotification(includeArguments = true)
        fun save(email: String, content: String): String = email + content
    }

    private fun report(reported: Member?): ContentReport {
        return ContentReport(
            reporter = memberWithId(id = 7L, name = "신고자"),
            reportedMember = reported,
            targetType = ReportTargetType.SCHEDULE,
            targetId = "9b7f1f0e-0000-0000-0000-000000000001",
            reason = ReportReason.HARASSMENT,
            detail = "욕설이 포함되어 있습니다",
            contentSnapshot = "제목: 회식\n내용: 설명\n첨부: 없음",
            reporterName = "신고자",
            reportedMemberName = "피신고자",
        )
    }

    private fun captured(): JsonObject {
        val messageCaptor = argumentCaptor<SlackMessage>()
        verify(notifier).call(messageCaptor.capture())
        return messageCaptor.firstValue.prepare()
    }

    private fun capturedAttachment(): JsonObject = captured()["attachments"].asJsonArray.single().asJsonObject

    private fun inquiry(subject: String?, content: String): Inquiry {
        return Inquiry(
            member = null,
            email = "g@example.com",
            subject = subject,
            content = content,
            ipAddress = "192.0.2.1",
        )
    }

    private fun memberWithId(id: Long, name: String): Member {
        val member = Member(name = name, email = "$name@duty.park", password = "password")
        ReflectionTestUtils.setField(member, "id", id)
        return member
    }
}
