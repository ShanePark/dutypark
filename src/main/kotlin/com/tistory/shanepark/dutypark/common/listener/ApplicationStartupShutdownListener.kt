package com.tistory.shanepark.dutypark.common.listener

import com.tistory.shanepark.dutypark.common.slack.notifier.SlackNotifier
import net.gpedro.integrations.slack.SlackMessage
import org.springframework.boot.context.event.ApplicationReadyEvent
import org.springframework.context.event.ContextClosedEvent
import org.springframework.context.event.EventListener
import org.springframework.core.env.Environment
import org.springframework.stereotype.Component
import kotlin.system.exitProcess

@Component
class ApplicationStartupShutdownListener(
    private val slackNotifier: SlackNotifier,
    private val environment: Environment
) {

    @EventListener(ApplicationReadyEvent::class)
    fun onApplicationReady(event: ApplicationReadyEvent) {
        val slackMessage = makeSlackMessage(text = "Application is ready")
        slackNotifier.call(slackMessage)
    }

    @EventListener(ContextClosedEvent::class)
    fun onApplicationShutdown(event: ContextClosedEvent) {
        val slackMessage = makeSlackMessage(text = "Application is shutting down")
        slackNotifier.call(slackMessage)
        if (!environment.activeProfiles.contains("test")) {
            exitProcess(0)
        }
    }

    fun makeSlackMessage(text: String): SlackMessage {
        val slackMessage = SlackMessage()
        slackMessage.setIcon(":computer:")
        slackMessage.setText(text)
        slackMessage.setUsername("DutyPark")
        return slackMessage
    }

}
