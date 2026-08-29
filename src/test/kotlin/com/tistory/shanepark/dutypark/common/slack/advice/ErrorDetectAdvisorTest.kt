package com.tistory.shanepark.dutypark.common.slack.advice

import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.core.read.ListAppender
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackNotifier
import net.gpedro.integrations.slack.SlackAttachment
import net.gpedro.integrations.slack.SlackException
import net.gpedro.integrations.slack.SlackField
import net.gpedro.integrations.slack.SlackMessage
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertDoesNotThrow
import org.junit.jupiter.api.assertThrows
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.verifyNoInteractions
import org.mockito.kotlin.any
import org.mockito.kotlin.whenever
import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException
import org.springframework.web.context.request.async.AsyncRequestNotUsableException
import org.apache.catalina.connector.ClientAbortException

class ErrorDetectAdvisorTest {

    private val slackNotifier: SlackNotifier = mock()
    private val advisor = ErrorDetectAdvisor(slackNotifier)

    @Test
    fun `handleMethodNotSupported returns 404`() {
        val request = MockHttpServletRequest()

        val response = advisor.handleMethodNotSupported(
            request,
            org.springframework.web.HttpRequestMethodNotSupportedException("POST")
        )

        assertThat(response.statusCode).isEqualTo(HttpStatus.NOT_FOUND)
    }

    @Test
    fun `handleIllegalArgumentException uses default message when empty`() {
        val request = MockHttpServletRequest()

        val response = advisor.handleIllegalArgumentException(request, IllegalArgumentException())

        assertThat(response.statusCode).isEqualTo(HttpStatus.BAD_REQUEST)
        assertThat(response.body?.get("error")).isEqualTo("Bad Request")
    }

    @Test
    fun `handleException skips notify for ignored exceptions`() {
        val request = MockHttpServletRequest()

        assertDoesNotThrow {
            advisor.handleException(request, AsyncRequestNotUsableException("ignored"))
        }

        verifyNoInteractions(slackNotifier)
    }

    @Test
    fun `handleException sends only the exception class`() {
        val request = requestWithBody("/api/private", "email=private@example.com&content=submitted-secret")
        request.queryString = "token=query-secret"
        val exception = RuntimeException("user supplied exception message")

        assertThrows<RuntimeException> {
            advisor.handleException(request, exception)
        }

        val message = captureSlackMessage()
        val attachment = readAttachments(message).single()
        assertThat(readFieldTitles(attachment)).containsExactly("Error Type")
        assertThat(findField(message, "Error Type")).isEqualTo("RuntimeException")
        assertThat(attachment.toJson()["text"]).isNull()
        assertThat(message.prepare().toString()).doesNotContain(
            "private@example.com",
            "submitted-secret",
            "query-secret",
            "127.0.0.1",
            "JUnit",
            "user supplied exception message",
            "RuntimeException:",
            "Request URL",
            "Request Body",
            "Request Parameters",
            "Request IP",
            "Request User-Agent",
        )
    }

    @Test
    fun `handleException keeps the original error when Slack sending fails`() {
        val request = requestWithBody("/api/private", "content=submitted-secret")
        val original = RuntimeException("original user supplied message")
        val webhookFailureMessage = "https://hooks.slack.com/services/T000/B000/secret-token"
        whenever(slackNotifier.call(any()))
            .thenThrow(SlackException(IllegalStateException(webhookFailureMessage)))

        val logger = LoggerFactory.getLogger(ErrorDetectAdvisor::class.java)
            as ch.qos.logback.classic.Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        val thrown = try {
            assertThrows<RuntimeException> {
                advisor.handleException(request, original)
            }
        } finally {
            logger.detachAppender(appender)
        }

        assertThat(thrown).isSameAs(original)
        assertThat(appender.list).hasSize(1)
        assertThat(appender.list.single().formattedMessage)
            .contains("SlackException")
            .doesNotContain(webhookFailureMessage, original.message)
        assertThat(appender.list.single().throwableProxy).isNull()
    }

    @Test
    fun `handleException skips notify for client abort`() {
        val request = MockHttpServletRequest()

        assertDoesNotThrow {
            advisor.handleException(request, ClientAbortException())
        }

        verifyNoInteractions(slackNotifier)
    }

    @Test
    fun `handleMethodArgumentTypeMismatch returns 400 and does not notify`() {
        val mismatchException = MethodArgumentTypeMismatchException(
            "NaN",
            Long::class.javaObjectType,
            "memberId",
            mock(),
            NumberFormatException("For input string: \"NaN\"")
        )

        val response = advisor.handleMethodArgumentTypeMismatch(mismatchException)

        assertThat(response.statusCode).isEqualTo(HttpStatus.BAD_REQUEST)
        verifyNoInteractions(slackNotifier)
    }

    private fun requestWithBody(uri: String, body: String): MockHttpServletRequest {
        val request = MockHttpServletRequest()
        request.method = "POST"
        request.requestURI = uri
        request.serverName = "localhost"
        request.remoteAddr = "127.0.0.1"
        request.characterEncoding = "UTF-8"
        request.addHeader("User-Agent", "JUnit")
        request.addParameter("q", "value")
        request.setContent(body.toByteArray())
        return request
    }

    private fun captureSlackMessage(): SlackMessage {
        val captor = argumentCaptor<SlackMessage>()
        verify(slackNotifier).call(captor.capture())
        return captor.firstValue
    }

    private fun findField(message: SlackMessage, title: String): String? {
        val attachments = readAttachments(message)
        val attachment = attachments.single()
        val fields = readFields(attachment)
        val match = fields.firstOrNull { readFieldTitle(it) == title }
        return match?.let { readFieldValue(it) }
    }

    @Suppress("UNCHECKED_CAST")
    private fun readAttachments(message: SlackMessage): List<SlackAttachment> {
        val field = SlackMessage::class.java.getDeclaredField("attach")
        field.isAccessible = true
        return field.get(message) as? List<SlackAttachment> ?: emptyList()
    }

    @Suppress("UNCHECKED_CAST")
    private fun readFields(attachment: SlackAttachment): List<SlackField> {
        val field = SlackAttachment::class.java.getDeclaredField("fields")
        field.isAccessible = true
        return field.get(attachment) as? List<SlackField> ?: emptyList()
    }

    private fun readFieldTitles(attachment: SlackAttachment): List<String?> = readFields(attachment).map(::readFieldTitle)

    private fun readFieldTitle(field: SlackField): String? {
        val titleField = SlackField::class.java.getDeclaredField("title")
        titleField.isAccessible = true
        return titleField.get(field) as? String
    }

    private fun readFieldValue(field: SlackField): String? {
        val valueField = SlackField::class.java.getDeclaredField("value")
        valueField.isAccessible = true
        return valueField.get(field) as? String
    }
}
