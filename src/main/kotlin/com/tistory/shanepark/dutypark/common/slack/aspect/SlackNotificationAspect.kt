package com.tistory.shanepark.dutypark.common.slack.aspect

import com.tistory.shanepark.dutypark.common.slack.notifier.SlackNotifier
import net.gpedro.integrations.slack.SlackAttachment
import net.gpedro.integrations.slack.SlackField
import net.gpedro.integrations.slack.SlackMessage
import org.aspectj.lang.ProceedingJoinPoint
import org.aspectj.lang.annotation.Around
import org.aspectj.lang.annotation.Aspect
import org.aspectj.lang.reflect.MethodSignature
import org.springframework.beans.factory.annotation.Qualifier
import org.springframework.core.task.TaskExecutor
import org.springframework.stereotype.Component

@Aspect
@Component
class SlackNotificationAspect(
    private val slackNotifier: SlackNotifier,
    @Qualifier("slackTaskExecutor")
    private val taskExecutor: TaskExecutor,
) {
    @Around("@annotation(com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification)")
    fun slackNotification(proceedingJoinPoint: ProceedingJoinPoint): Any? {
        val arguments = (proceedingJoinPoint.signature as MethodSignature).method.parameters
            .map { it.name }
            .zip(proceedingJoinPoint.args)
            .joinToString { "${it.first} : ${it.second}" }

        val slackAttachment = SlackAttachment()
        slackAttachment.setFallback("Post")
        slackAttachment.setColor("good")
        slackAttachment.setTitle("Data save detected")

        slackAttachment.setFields(
            listOf(
                SlackField().setTitle("Arguments").setValue(arguments),
                SlackField().setTitle("method").setValue(proceedingJoinPoint.signature.name),
            )
        )

        val slackMessage = SlackMessage()
        slackMessage.setAttachments(listOf(slackAttachment))
        slackMessage.setIcon(":floppy_disk:")
        slackMessage.setText("Post Request")
        slackMessage.setUsername("DutyPark")

        taskExecutor.execute {
            slackNotifier.call(slackMessage)
        }

        return proceedingJoinPoint.proceed()
    }

}
