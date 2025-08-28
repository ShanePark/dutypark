package com.tistory.shanepark.dutypark.common.listener

import com.tistory.shanepark.dutypark.common.slack.notifier.SlackNotifier
import net.gpedro.integrations.slack.SlackMessage
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.context.event.ApplicationReadyEvent
import org.springframework.context.annotation.PropertySource
import org.springframework.context.event.ContextClosedEvent
import org.springframework.context.event.EventListener
import org.springframework.stereotype.Component

@Component
@PropertySource("classpath:git.properties", ignoreResourceNotFound = true)
class ApplicationStartupShutdownListener(
    private val slackNotifier: SlackNotifier,
    @param:Value("\${git.commit.id.abbrev:unknown}") private val commitId: String,
    @param:Value("\${git.branch:unknown}") private val branch: String,
) {
    @EventListener(ApplicationReadyEvent::class)
    fun onApplicationReady() {
        val slackMessage = makeSlackMessage(text = "Application is ready (branch: $branch, commit: $commitId)")
        slackNotifier.call(slackMessage)
    }

    @EventListener(ContextClosedEvent::class)
    fun onApplicationShutdown() {
        val slackMessage = makeSlackMessage(text = "Application is shutting down")
        slackNotifier.call(slackMessage)
    }

    fun makeSlackMessage(text: String): SlackMessage {
        val slackMessage = SlackMessage()
        slackMessage.setIcon(":computer:")
        slackMessage.setText(text)
        slackMessage.setUsername("DutyPark")
        return slackMessage
    }

}
