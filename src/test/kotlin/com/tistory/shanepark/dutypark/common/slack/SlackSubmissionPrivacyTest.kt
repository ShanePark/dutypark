package com.tistory.shanepark.dutypark.common.slack

import com.google.gson.JsonObject
import com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackEventNotifier
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackNotifier
import com.tistory.shanepark.dutypark.inquiry.domain.dto.CreateInquiryRequest
import com.tistory.shanepark.dutypark.inquiry.domain.entity.Inquiry
import com.tistory.shanepark.dutypark.inquiry.service.InquirySlackNotifier
import com.tistory.shanepark.dutypark.inquiry.service.InquiryService
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.report.domain.dto.CreateReportRequest
import com.tistory.shanepark.dutypark.report.domain.dto.ReportCreateResult
import com.tistory.shanepark.dutypark.report.domain.enums.ReportReason
import com.tistory.shanepark.dutypark.report.domain.enums.ReportTargetType
import com.tistory.shanepark.dutypark.report.service.ReportService
import com.tistory.shanepark.dutypark.report.service.ReportSlackNotifier
import net.gpedro.integrations.slack.SlackMessage
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
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
    fun `inquiry notification fits one block with masked contact and network identifiers`() {
        val inquiry = Inquiry(
            member = memberWithId(id = 42L, name = "홍길동"),
            email = "private@example.com",
            subject = "일정이 보이지 않습니다",
            content = "8월 일정이 사라졌어요",
            ipAddress = "192.0.2.1",
        )

        InquirySlackNotifier(eventNotifier).inquiryCreated(inquiry)

        val attachment = capturedAttachment()
        assertThat(attachment["title"].asString).isEqualTo("📩 New inquiry  ·  Member 홍길동 (#42)")
        assertThat(attachment["text"].asString).isEqualTo(
            """
            *일정이 보이지 않습니다*
            `pr***@example.com`  `192.0.2.***`
            > 8월 일정이 사라졌어요
            """.trimIndent()
        )
        assertThat(attachment["footer"].asString).isEqualTo(inquiry.id.toString().take(8))
        assertThat(attachment["color"].asString).isEqualTo(SlackEventLevel.INFO.color)
        assertThat(captured().toString()).doesNotContain("private@example.com", "192.0.2.1")
    }

    @Test
    fun `guest inquiry without a subject does not spend a line on it`() {
        val inquiry = Inquiry(
            member = null,
            email = "g@example.com",
            subject = null,
            content = "비회원 문의입니다",
            ipAddress = "2001:db8:85a3::8a2e:370:7334",
        )

        InquirySlackNotifier(eventNotifier).inquiryCreated(inquiry)

        val attachment = capturedAttachment()
        assertThat(attachment["title"].asString).isEqualTo("📩 New inquiry  ·  Guest")
        assertThat(attachment["text"].asString).isEqualTo(
            """
            `g***@example.com`  `2001:db8:***`
            > 비회원 문의입니다
            """.trimIndent()
        )
    }

    @Test
    fun `long inquiry content is previewed instead of copied in full`() {
        InquirySlackNotifier(eventNotifier).inquiryCreated(inquiry(subject = null, content = "가".repeat(400)))

        assertThat(capturedAttachment()["text"].asString)
            .endsWith("> " + "가".repeat(300) + "… (+100 chars)")
    }

    @Test
    fun `multi line body stays inside the quote block`() {
        InquirySlackNotifier(eventNotifier).inquiryCreated(inquiry(subject = null, content = "첫 줄\n둘째 줄"))

        assertThat(capturedAttachment()["text"].asString).endsWith("> 첫 줄\n> 둘째 줄")
    }

    @Test
    fun `report notification carries the moderation context of the incoming request`() {
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
        assertThat(attachment["title"].asString).isEqualTo("🚨 New report  ·  신고자 (#7) → 피신고자 (#9)")
        assertThat(attachment["text"].asString).isEqualTo(
            """
            *HARASSMENT*
            `SCHEDULE`  `also blocked`
            > 욕설이 포함되어 있습니다
            """.trimIndent()
        )
        assertThat(attachment["footer"].asString).isEqualTo("${reportId.toString().take(8)}  ·  target 9b7f1f0e")
        assertThat(attachment["color"].asString).isEqualTo(SlackEventLevel.NOTICE.color)
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
        assertThat(attachment["color"].asString).isEqualTo(SlackEventLevel.MUTED.color)
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
