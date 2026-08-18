package com.tistory.shanepark.dutypark.common.slack

import com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification
import com.tistory.shanepark.dutypark.common.slack.aspect.SlackNotificationAspect
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackNotifier
import com.tistory.shanepark.dutypark.inquiry.domain.dto.CreateInquiryRequest
import com.tistory.shanepark.dutypark.inquiry.service.InquiryService
import com.tistory.shanepark.dutypark.report.domain.dto.CreateReportRequest
import com.tistory.shanepark.dutypark.report.service.ReportService
import net.gpedro.integrations.slack.SlackAttachment
import net.gpedro.integrations.slack.SlackField
import net.gpedro.integrations.slack.SlackMessage
import org.aspectj.lang.ProceedingJoinPoint
import org.aspectj.lang.reflect.MethodSignature
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.springframework.core.task.SyncTaskExecutor

class SlackSubmissionPrivacyTest {

    @Test
    fun `submission service methods disable Slack argument collection`() {
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

        assertThat(createInquiry.getAnnotation(SlackNotification::class.java).includeArguments).isFalse()
        assertThat(createReport.getAnnotation(SlackNotification::class.java).includeArguments).isFalse()
    }

    @Test
    fun `disabled argument collection sends an operational signal without sensitive values`() {
        val notifier = mock<SlackNotifier>()
        val joinPoint = mock<ProceedingJoinPoint>()
        val signature = mock<MethodSignature>()
        val method = InquiryService::class.java.getMethod(
            "createInquiry",
            Long::class.javaObjectType,
            CreateInquiryRequest::class.java,
            String::class.java,
        )
        whenever(joinPoint.proceed()).thenReturn("result")
        whenever(joinPoint.signature).thenReturn(signature)
        whenever(signature.method).thenReturn(method)
        whenever(signature.name).thenReturn("createInquiry")
        whenever(joinPoint.args).thenReturn(
            arrayOf<Any?>(42L, "email=private@example.com, content=secret", "192.0.2.1")
        )

        val result = SlackNotificationAspect(notifier, SyncTaskExecutor()).slackNotification(joinPoint)

        assertThat(result).isEqualTo("result")
        val messageCaptor = argumentCaptor<SlackMessage>()
        verify(notifier).call(messageCaptor.capture())
        val fields = fieldsOf(messageCaptor.firstValue)
        assertThat(fields.mapNotNull(::fieldTitle)).containsExactly("method")
        assertThat(fields.single().let(::fieldValue)).isEqualTo("createInquiry")
        assertThat(messageCaptor.firstValue.toString())
            .doesNotContain("42", "private@example.com", "secret", "192.0.2.1")
    }

    @Suppress("UNCHECKED_CAST")
    private fun fieldsOf(message: SlackMessage): List<SlackField> {
        val attachmentsField = SlackMessage::class.java.getDeclaredField("attach").apply { isAccessible = true }
        val attachment = (attachmentsField.get(message) as List<SlackAttachment>).single()
        val fieldsField = SlackAttachment::class.java.getDeclaredField("fields").apply { isAccessible = true }
        return fieldsField.get(attachment) as List<SlackField>
    }

    private fun fieldTitle(field: SlackField): String? {
        return SlackField::class.java.getDeclaredField("title").apply { isAccessible = true }.get(field) as? String
    }

    private fun fieldValue(field: SlackField): String? {
        return SlackField::class.java.getDeclaredField("value").apply { isAccessible = true }.get(field) as? String
    }
}
