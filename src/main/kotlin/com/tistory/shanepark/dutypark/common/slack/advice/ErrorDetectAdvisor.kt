package com.tistory.shanepark.dutypark.common.slack.advice

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackNotifier
import jakarta.servlet.http.HttpServletRequest
import net.gpedro.integrations.slack.SlackAttachment
import net.gpedro.integrations.slack.SlackField
import net.gpedro.integrations.slack.SlackMessage
import org.apache.catalina.connector.ClientAbortException
import org.apache.coyote.CloseNowException
import org.springframework.http.ResponseEntity
import org.springframework.web.HttpRequestMethodNotSupportedException
import org.springframework.web.bind.annotation.ControllerAdvice
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.ResponseBody
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException
import org.springframework.web.context.request.async.AsyncRequestNotUsableException
import org.springframework.web.servlet.resource.NoResourceFoundException
import java.util.Collections

@ControllerAdvice
class ErrorDetectAdvisor(
    private val slackNotifier: SlackNotifier,
) {
    private val log = logger()

    private companion object {
        private val NOT_NOTIFY_EXCEPTIONS: Set<Class<out Exception>> = setOf(
            NoResourceFoundException::class.java,
            ClientAbortException::class.java,
            CloseNowException::class.java,
            AsyncRequestNotUsableException::class.java
        )
    }

    @ExceptionHandler(HttpRequestMethodNotSupportedException::class)
    @ResponseBody
    fun handleMethodNotSupported(
        req: HttpServletRequest,
        e: HttpRequestMethodNotSupportedException
    ): ResponseEntity<Void> {
        return ResponseEntity.status(404).build()
    }

    @ExceptionHandler(IllegalArgumentException::class)
    @ResponseBody
    fun handleIllegalArgumentException(
        req: HttpServletRequest,
        e: IllegalArgumentException
    ): ResponseEntity<Map<String, String>> {
        return ResponseEntity.badRequest().body(mapOf("error" to (e.message ?: "Bad Request")))
    }

    @ExceptionHandler(MethodArgumentTypeMismatchException::class)
    @ResponseBody
    fun handleMethodArgumentTypeMismatch(
        e: MethodArgumentTypeMismatchException
    ): ResponseEntity<Map<String, String>> {
        return ResponseEntity.badRequest().body(mapOf("error" to e.message))
    }

    @ExceptionHandler(Exception::class)
    fun handleException(_req: HttpServletRequest, e: Exception) {
        if (isNotNotify(e))
            return

        val slackAttachment = SlackAttachment()
        slackAttachment.setFallback("Error")
        slackAttachment.setColor("danger")
        slackAttachment.setTitle("Error Detect")
        slackAttachment.setFields(
            listOf(
                SlackField().setTitle("Error Type").setValue(exceptionType(e)),
            )
        )

        val slackMessage = SlackMessage()
        slackMessage.setAttachments(Collections.singletonList(slackAttachment))
        slackMessage.setIcon(":ghost:")
        slackMessage.setText("")
        slackMessage.setUsername("DutyPark")

        try {
            slackNotifier.call(slackMessage)
        } catch (notificationFailure: Throwable) {
            log.error(
                "Failed to send Slack notification (exception={})",
                notificationFailure.javaClass.name,
            )
        }
        throw e
    }

    /** 예외 클래스명은 운영 분류에 필요하지만 예외 메시지·stack trace는 사용자 입력을 포함할 수 있다. */
    private fun exceptionType(e: Exception): String = e.javaClass.simpleName.ifEmpty { e.javaClass.name }

    private fun isNotNotify(e: Exception): Boolean {
        return NOT_NOTIFY_EXCEPTIONS.any { exceptionType -> exceptionType.isInstance(e) }
    }

}
