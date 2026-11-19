package com.tistory.shanepark.dutypark.common.slack.advice

import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.core.read.ListAppender
import com.google.gson.JsonObject
import com.tistory.shanepark.dutypark.common.slack.SlackEventLevel
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackEventNotifier
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackNotifier
import net.gpedro.integrations.slack.SlackMessage
import org.apache.catalina.connector.ClientAbortException
import org.apache.coyote.CloseNowException
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Timeout
import org.junit.jupiter.api.assertDoesNotThrow
import org.junit.jupiter.api.assertThrows
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.verifyNoInteractions
import org.slf4j.LoggerFactory
import org.springframework.core.task.SyncTaskExecutor
import org.springframework.core.task.TaskExecutor
import org.springframework.core.task.TaskRejectedException
import org.springframework.http.HttpStatus
import org.springframework.http.converter.HttpMessageNotWritableException
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException
import org.springframework.web.context.request.async.AsyncRequestNotUsableException
import org.springframework.web.servlet.HandlerMapping
import java.io.IOException
import java.util.concurrent.TimeUnit

class ErrorDetectAdvisorTest {

    private val slackNotifier: SlackNotifier = mock()
    private val advisor = ErrorDetectAdvisor(SlackEventNotifier(slackNotifier, SyncTaskExecutor()))

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
    fun `handleException sends only the exception class and request method`() {
        val request = requestWithBody("/api/private", "email=private@example.com&content=submitted-secret")
        request.queryString = "token=query-secret"
        val exception = RuntimeException("user supplied exception message")

        assertThrows<RuntimeException> {
            advisor.handleException(request, exception)
        }

        val message = captureSlackMessage()
        val attachment = attachmentOf(message)
        assertThat(attachment["title"].asString).isEqualTo("🔥 Unhandled error")
        assertThat(attachment["text"].asString).isEqualTo("*RuntimeException*\n`POST`  `&lt;unmatched&gt;`")
        assertThat(attachment["color"].asString).isEqualTo(SlackEventLevel.ALERT.color)
        assertThat(attachment["fields"]).isNull()
        assertThat(message.prepare().toString()).doesNotContain(
            "/api/private",
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
    fun `handleException logs mapped request and exception trace without messages`() {
        val request = requestWithBody(
            "/api/attachments/attachment-secret/download",
            "email=private@example.com&content=submitted-secret",
        ).apply {
            method = "GET"
            queryString = "token=query-secret"
            setAttribute(HandlerMapping.BEST_MATCHING_PATTERN_ATTRIBUTE, "/api/attachments/{id}/download")
        }
        val exception = HttpMessageNotWritableException(
            "private@example.com response value",
            IllegalStateException("submitted-secret serialization detail"),
        )
        val logger = LoggerFactory.getLogger(ErrorDetectAdvisor::class.java)
            as ch.qos.logback.classic.Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)

        try {
            assertThrows<HttpMessageNotWritableException> {
                advisor.handleException(request, exception)
            }
        } finally {
            logger.detachAppender(appender)
        }

        assertThat(appender.list).hasSize(1)
        val event = appender.list.single()
        assertThat(event.formattedMessage)
            .contains(
                "method=GET",
                "pathPattern=/api/attachments/{id}/download",
                "HttpMessageNotWritableException",
                "IllegalStateException",
                "ErrorDetectAdvisorTest.handleException logs mapped request",
            )
            .doesNotContain(
                "attachment-secret",
                "query-secret",
                "private@example.com",
                "submitted-secret",
            )
        assertThat(event.throwableProxy).isNull()
        val slackText = attachmentOf(captureSlackMessage())["text"].asString
        assertThat(slackText)
            .isEqualTo("*HttpMessageNotWritableException*\n`GET`  `/api/attachments/{id}/download`")
            .doesNotContain("attachment-secret", "query-secret", "private@example.com", "submitted-secret")
    }

    @Test
    fun `handleException does not log raw URI when request has no route pattern`() {
        val request = requestWithBody("/api/private/member-secret", "")
        request.method = "GET"
        request.queryString = "token=query-secret"
        val logger = LoggerFactory.getLogger(ErrorDetectAdvisor::class.java)
            as ch.qos.logback.classic.Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)

        try {
            assertThrows<RuntimeException> {
                advisor.handleException(request, RuntimeException("private exception message"))
            }
        } finally {
            logger.detachAppender(appender)
        }

        assertThat(appender.list).hasSize(1)
        assertThat(appender.list.single().formattedMessage)
            .contains("method=GET", "pathPattern=<unmatched>")
            .doesNotContain("/api/private/member-secret", "query-secret", "private exception message")
    }

    @Test
    fun `handleException keeps the original error when Slack submission fails`() {
        val request = requestWithBody("/api/private", "content=submitted-secret")
        val original = RuntimeException("original user supplied message")
        val webhookFailureMessage = "https://hooks.slack.com/services/T000/B000/secret-token"
        val rejectingExecutor = TaskExecutor { throw TaskRejectedException(webhookFailureMessage) }
        val advisor = ErrorDetectAdvisor(SlackEventNotifier(slackNotifier, rejectingExecutor))

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
        assertThat(appender.list).hasSize(2)
        val slackFailureLog = appender.list.first()
        assertThat(slackFailureLog.formattedMessage)
            .contains("TaskRejectedException")
            .doesNotContain(webhookFailureMessage, original.message)
        val diagnosticLog = appender.list.last()
        assertThat(diagnosticLog.formattedMessage)
            .contains("Unhandled request exception", "pathPattern=<unmatched>", "RuntimeException")
            .doesNotContain(webhookFailureMessage, original.message)
        assertThat(appender.list).allSatisfy { assertThat(it.throwableProxy).isNull() }
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
    fun `handleException skips wrapped response connection failures`() {
        val request = MockHttpServletRequest()
        val ioFailure = IOException("socket closed")
        val wrappedExceptions = listOf(
            IllegalStateException(
                "response conversion failed",
                AsyncRequestNotUsableException("response is unusable", ClientAbortException(ioFailure)),
            ),
            ClientAbortException(ioFailure),
            CloseNowException("connection closed"),
        )
        val logger = LoggerFactory.getLogger(ErrorDetectAdvisor::class.java)
            as ch.qos.logback.classic.Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)

        try {
            wrappedExceptions.forEach { connectionFailure ->
                val exception = HttpMessageNotWritableException("response write failed", connectionFailure)
                assertDoesNotThrow { advisor.handleException(request, exception) }
            }
        } finally {
            logger.detachAppender(appender)
        }

        verifyNoInteractions(slackNotifier)
        assertThat(appender.list).isEmpty()
    }

    @Test
    @Timeout(value = 2, unit = TimeUnit.SECONDS)
    fun `handleException logs and notifies for cyclic non-connection cause chain`() {
        val request = MockHttpServletRequest()
        val exception = HttpMessageNotWritableException("write failed", CyclicCauseException())
        val logger = LoggerFactory.getLogger(ErrorDetectAdvisor::class.java)
            as ch.qos.logback.classic.Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)

        try {
            assertThrows<HttpMessageNotWritableException> {
                advisor.handleException(request, exception)
            }
        } finally {
            logger.detachAppender(appender)
        }

        assertThat(attachmentOf(captureSlackMessage())["text"].asString)
            .startsWith("*HttpMessageNotWritableException*")
        assertThat(appender.list).hasSize(1)
        assertThat(appender.list.single().formattedMessage)
            .contains("HttpMessageNotWritableException", "CyclicCauseException")
            .doesNotContain("write failed", "cyclic-cause-private-message")
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

    private class CyclicCauseException : RuntimeException("cyclic-cause-private-message") {
        override val cause: Throwable
            get() = this
    }

    private fun captureSlackMessage(): SlackMessage {
        val captor = argumentCaptor<SlackMessage>()
        verify(slackNotifier).call(captor.capture())
        return captor.firstValue
    }

    private fun attachmentOf(message: SlackMessage): JsonObject =
        message.prepare()["attachments"].asJsonArray.single().asJsonObject
}
