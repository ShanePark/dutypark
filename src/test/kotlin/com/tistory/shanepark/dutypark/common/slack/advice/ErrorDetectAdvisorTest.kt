package com.tistory.shanepark.dutypark.common.slack.advice

import com.tistory.shanepark.dutypark.common.slack.notifier.SlackNotifier
import net.gpedro.integrations.slack.SlackAttachment
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
import org.springframework.http.HttpStatus
import org.springframework.mock.web.MockHttpServletRequest
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
    fun `handleException redacts auth request body`() {
        val request = requestWithBody("/api/auth/token", "secret=1")

        assertThrows<RuntimeException> {
            advisor.handleException(request, RuntimeException("boom"))
        }

        val message = captureSlackMessage()
        val bodyField = findField(message, "Request Body")
        assertThat(bodyField).isEqualTo("[REDACTED]")
    }

    @Test
    fun `handleException clears body when payload is too large`() {
        val request = requestWithBody("/api/other", "a".repeat(600))

        assertThrows<RuntimeException> {
            advisor.handleException(request, RuntimeException("boom"))
        }

        val message = captureSlackMessage()
        val bodyField = findField(message, "Request Body")
        assertThat(bodyField).isEqualTo("")
    }

    @Test
    fun `handleException captures body for normal requests`() {
        val request = requestWithBody("/api/other", "payload")

        assertThrows<RuntimeException> {
            advisor.handleException(request, RuntimeException("boom"))
        }

        val message = captureSlackMessage()
        val bodyField = findField(message, "Request Body")
        assertThat(bodyField).isEqualTo("payload")
    }

    @Test
    fun `handleException skips notify for client abort`() {
        val request = MockHttpServletRequest()

        assertDoesNotThrow {
            advisor.handleException(request, ClientAbortException())
        }

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
