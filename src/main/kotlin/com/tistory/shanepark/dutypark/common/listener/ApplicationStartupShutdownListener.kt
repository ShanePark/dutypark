package com.tistory.shanepark.dutypark.common.listener

import com.tistory.shanepark.dutypark.common.slack.SlackEvent
import com.tistory.shanepark.dutypark.common.slack.SlackEventLevel
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackEventNotifier
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.context.event.ApplicationReadyEvent
import org.springframework.context.event.ContextClosedEvent
import org.springframework.context.event.EventListener
import org.springframework.stereotype.Component

@Component
class ApplicationStartupShutdownListener(
    private val slackEventNotifier: SlackEventNotifier,
    @param:Value("\${git.commit.id.abbrev:unknown}") private val commitId: String,
    @param:Value("\${git.branch:unknown}") private val branch: String,
) {
    @EventListener(ApplicationReadyEvent::class)
    fun onApplicationReady() {
        slackEventNotifier.send(
            SlackEvent(
                emoji = "🟢",
                title = "Application ready",
                chips = listOf(branch, commitId),
            )
        )
    }

    /** 슬랙 executor 도 같은 이벤트에서 닫히기 시작하므로 이 스레드에서 바로 보낸다. */
    @EventListener(ContextClosedEvent::class)
    fun onApplicationShutdown() {
        slackEventNotifier.sendNow(
            SlackEvent(
                emoji = "🔴",
                title = "Application shutting down",
                level = SlackEventLevel.MUTED,
            )
        )
    }

}
