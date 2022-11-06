package com.tistory.shanepark.dutypark.common.slack.aspect

import net.gpedro.integrations.slack.SlackApi
import net.gpedro.integrations.slack.SlackAttachment
import net.gpedro.integrations.slack.SlackField
import net.gpedro.integrations.slack.SlackMessage
import org.aspectj.lang.ProceedingJoinPoint
import org.aspectj.lang.annotation.Around
import org.aspectj.lang.annotation.Aspect
import org.springframework.core.task.TaskExecutor
import org.springframework.stereotype.Component

@Aspect
@Component
class SlackNotificationAspect(
    private val slackApi: SlackApi,
    private val taskExecutor: TaskExecutor,
) {

    @Around("@annotation(com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification)")
    fun slackNotification(proceedingJoinPoint: ProceedingJoinPoint): Any? {

        // it keeps sending Slack message. After enough test done, remove this aop.
        val slackAttachment = SlackAttachment()
        slackAttachment.setFallback("Post")
        slackAttachment.setColor("good")
        slackAttachment.setTitle("Data save detected")
        slackAttachment.setFields(
            listOf(
                SlackField().setTitle("Arguments").setValue(proceedingJoinPoint.args.joinToString()),
                SlackField().setTitle("method").setValue(proceedingJoinPoint.signature.name),
            )
        )

        val slackMessage = SlackMessage()
        slackMessage.setAttachments(listOf(slackAttachment))
        slackMessage.setIcon(":floppy_disk:")
        slackMessage.setText("Post Request")
        slackMessage.setUsername("DutyPark")

        taskExecutor.execute {
            slackApi.call(slackMessage)
        }

        return proceedingJoinPoint.proceed()
    }

}
