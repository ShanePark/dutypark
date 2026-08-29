package com.tistory.shanepark.dutypark.common.slack.aspect

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackNotifier
import net.gpedro.integrations.slack.SlackAttachment
import net.gpedro.integrations.slack.SlackField
import net.gpedro.integrations.slack.SlackMessage
import org.aspectj.lang.ProceedingJoinPoint
import org.aspectj.lang.annotation.Around
import org.aspectj.lang.annotation.Aspect
import org.springframework.beans.factory.annotation.Qualifier
import org.springframework.core.task.TaskExecutor
import org.springframework.stereotype.Component

@Aspect
@Component
class SlackNotificationAspect(
    private val slackNotifier: SlackNotifier,
    @param:Qualifier("slackTaskExecutor")
    private val taskExecutor: TaskExecutor,
) {
    val log = logger()

    @Around("@annotation(com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification)")
    fun slackNotification(proceedingJoinPoint: ProceedingJoinPoint): Any? {
        return try {
            val result = proceedingJoinPoint.proceed()

            val slackAttachment = SlackAttachment()
            slackAttachment.setFallback("Post")
            slackAttachment.setColor("good")
            slackAttachment.setTitle("Data save detected")

            // Method arguments can contain request DTOs, credentials, or user text. The annotation's
            // includeArguments flag is retained for source compatibility but is intentionally ignored.
            slackAttachment.setFields(
                listOf(SlackField().setTitle("method").setValue(proceedingJoinPoint.signature.name))
            )

            val slackMessage = SlackMessage()
            slackMessage.setAttachments(listOf(slackAttachment))
            slackMessage.setIcon(":floppy_disk:")
            slackMessage.setText("Post Request")
            slackMessage.setUsername("DutyPark")

            taskExecutor.execute {
                runCatching { slackNotifier.call(slackMessage) }
                    .onFailure { failure ->
                        log.error(
                            "Failed to send Slack notification (exception={})",
                            failure.javaClass.name,
                        )
                    }
            }

            result
        } catch (ex: Exception) {
            // Exception messages and stack traces may echo request data. Keep this operational log
            // classification-only as well; the original exception is still propagated unchanged.
            log.error(
                "Failed to send Slack notification (exception={})",
                ex.javaClass.name,
            )
            throw ex
        }
    }

}
