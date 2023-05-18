package com.tistory.shanepark.dutypark.common.slack.aspect

import com.tistory.shanepark.dutypark.common.slack.notifier.SlackNotifier
import net.gpedro.integrations.slack.SlackAttachment
import net.gpedro.integrations.slack.SlackField
import net.gpedro.integrations.slack.SlackMessage
import org.aspectj.lang.ProceedingJoinPoint
import org.aspectj.lang.annotation.Around
import org.aspectj.lang.annotation.Aspect
import org.springframework.beans.factory.annotation.Value
import org.springframework.core.task.TaskExecutor
import org.springframework.stereotype.Component
import java.time.LocalDateTime
import java.util.concurrent.atomic.AtomicLong

@Aspect
@Component
class SlackNotificationAspect(
    private val slackNotifier: SlackNotifier,
    private val taskExecutor: TaskExecutor,
    @param:Value("\${dutypark.slack.minimum-interval:60}")
    private val minimumSlackInterval: Long
) {
    private val lastSlackSent = AtomicLong(0)

    @Around("@annotation(com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification)")
    fun slackNotification(proceedingJoinPoint: ProceedingJoinPoint): Any? {
        synchronized(this) {
            val currentEpochSecond = LocalDateTime.now().toEpochSecond(java.time.ZoneOffset.UTC)
            if (currentEpochSecond - lastSlackSent.get() < minimumSlackInterval) {
                return proceedingJoinPoint.proceed()
            }
            lastSlackSent.set(currentEpochSecond)
        }

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
            slackNotifier.call(slackMessage)
        }

        return proceedingJoinPoint.proceed()
    }

}
