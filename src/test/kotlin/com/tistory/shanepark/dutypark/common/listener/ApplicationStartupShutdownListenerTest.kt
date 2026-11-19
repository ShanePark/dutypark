package com.tistory.shanepark.dutypark.common.listener

import com.google.gson.JsonObject
import com.tistory.shanepark.dutypark.common.slack.SlackEventLevel
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackEventNotifier
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackNotifier
import net.gpedro.integrations.slack.SlackMessage
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.springframework.core.task.SyncTaskExecutor
import org.springframework.core.task.TaskExecutor
import org.springframework.core.task.TaskRejectedException

class ApplicationStartupShutdownListenerTest {

    private val notifier: SlackNotifier = mock()

    @Test
    fun `ready alert shows the deployed branch and commit`() {
        listener(SyncTaskExecutor()).onApplicationReady()

        val attachment = capturedAttachment()
        assertThat(attachment["title"].asString).isEqualTo("🟢 Application ready")
        assertThat(attachment["text"].asString).isEqualTo("`main`  `a57ce8a`")
        assertThat(attachment["color"].asString).isEqualTo(SlackEventLevel.INFO.color)
    }

    @Test
    fun `shutdown alert is delivered even after the Slack executor stops accepting tasks`() {
        val closedExecutor = TaskExecutor { throw TaskRejectedException("executor shut down") }

        listener(closedExecutor).onApplicationShutdown()

        val attachment = capturedAttachment()
        assertThat(attachment["title"].asString).isEqualTo("🔴 Application shutting down")
        assertThat(attachment["color"].asString).isEqualTo(SlackEventLevel.MUTED.color)
    }

    private fun listener(executor: TaskExecutor) = ApplicationStartupShutdownListener(
        slackEventNotifier = SlackEventNotifier(notifier, executor),
        commitId = "a57ce8a",
        branch = "main",
    )

    private fun capturedAttachment(): JsonObject {
        val captor = argumentCaptor<SlackMessage>()
        verify(notifier).call(captor.capture())
        return captor.firstValue.prepare()["attachments"].asJsonArray.single().asJsonObject
    }
}
