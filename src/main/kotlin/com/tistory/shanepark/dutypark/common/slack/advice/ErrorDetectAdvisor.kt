package com.tistory.shanepark.dutypark.common.slack.advice

import jakarta.servlet.http.HttpServletRequest
import net.gpedro.integrations.slack.SlackApi
import net.gpedro.integrations.slack.SlackAttachment
import net.gpedro.integrations.slack.SlackField
import net.gpedro.integrations.slack.SlackMessage
import org.slf4j.Logger
import org.springframework.http.ResponseEntity
import org.springframework.web.HttpRequestMethodNotSupportedException
import org.springframework.web.bind.annotation.ControllerAdvice
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.ResponseBody
import java.util.*

@ControllerAdvice
class ErrorDetectAdvisor(
    private val slackApi: SlackApi,
) {
    val log: Logger = org.slf4j.LoggerFactory.getLogger(this.javaClass)

    @ExceptionHandler(HttpRequestMethodNotSupportedException::class)
    @ResponseBody
    fun handleMethodNotSupported(
        req: HttpServletRequest,
        e: HttpRequestMethodNotSupportedException
    ): ResponseEntity<Any> {
        val requestURI = req.requestURI
        if (!requestURI.equals("/")) {
            log.info("${e.message}, requestURI: $requestURI")
        }
        return ResponseEntity.status(404).build()
    }

    @ExceptionHandler(Exception::class)
    fun handleException(req: HttpServletRequest, e: Exception) {

        val slackAttachment = SlackAttachment()
        slackAttachment.setFallback("Error")
        slackAttachment.setColor("danger")
        slackAttachment.setTitle("Error Detect")
        slackAttachment.setTitleLink(req.contextPath)
        slackAttachment.setText(e.stackTraceToString())
        slackAttachment.setColor("danger")
        slackAttachment.setFields(
            listOf(
                SlackField().setTitle("Request URL").setValue(req.requestURL.toString()),
                SlackField().setTitle("Request Method").setValue(req.method),
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

        slackApi.call(slackMessage)
        throw e
    }

}
