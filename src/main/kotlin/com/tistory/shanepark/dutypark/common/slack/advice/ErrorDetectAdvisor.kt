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
import org.springframework.web.context.request.async.AsyncRequestNotUsableException
import org.springframework.web.servlet.resource.NoResourceFoundException
import java.util.*

@ControllerAdvice
class ErrorDetectAdvisor(
    private val slackNotifier: SlackNotifier,
) {
    private val log = logger()

    @ExceptionHandler(HttpRequestMethodNotSupportedException::class)
    @ResponseBody
    fun handleMethodNotSupported(
        req: HttpServletRequest,
        e: HttpRequestMethodNotSupportedException
    ): ResponseEntity<Void> {
        val requestURI = req.requestURI
        if (!requestURI.equals("/")) {
            log.info("MethodNotSupportedException ${e.message}, requestURI: $requestURI")
        }
        return ResponseEntity.status(404).build()
    }

    @ExceptionHandler(Exception::class)
    fun handleException(req: HttpServletRequest, e: Exception) {
        if (isNotNotify(e))
            return

        val slackAttachment = SlackAttachment()
        slackAttachment.setFallback("Error")
        slackAttachment.setColor("danger")
        slackAttachment.setTitle("Error Detect")
        slackAttachment.setTitleLink(req.contextPath)
        slackAttachment.setText(e.stackTraceToString())
        slackAttachment.setColor("danger")

        val parameters = req.parameterMap.map { (key, value) -> "$key: ${value.joinToString(",")}" }
        val body: String =
            if (req.contentLength > 500) "" else req.reader.lines().reduce { acc, line -> "$acc\n$line" }.orElse("")

        slackAttachment.setFields(
            listOf(
                SlackField().setTitle("Request URL").setValue(req.requestURL.toString()),
                SlackField().setTitle("Request Method").setValue(req.method),
                SlackField().setTitle("Request Parameters").setValue(parameters.joinToString("\n")),
                SlackField().setTitle("Request Body").setValue(body),
                SlackField().setTitle("Request Time").setValue(Date().toString()),
                SlackField().setTitle("Request IP").setValue(req.remoteAddr),
                SlackField().setTitle("Request User-Agent").setValue(req.getHeader("User-Agent")),
            )
        )

        val slackMessage = SlackMessage()
        slackMessage.setAttachments(Collections.singletonList(slackAttachment))
        slackMessage.setIcon(":ghost:")
        slackMessage.setText("Error Detect")
        slackMessage.setUsername("DutyPark")

        slackNotifier.call(slackMessage)
        throw e
    }

    private fun isNotNotify(e: Exception) =
        e is NoResourceFoundException || e is ClientAbortException || e is CloseNowException || e is AsyncRequestNotUsableException

}
