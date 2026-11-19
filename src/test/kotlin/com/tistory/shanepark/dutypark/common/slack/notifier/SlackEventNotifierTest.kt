package com.tistory.shanepark.dutypark.common.slack.notifier

import com.google.gson.JsonObject
import com.tistory.shanepark.dutypark.common.slack.SlackEvent
import net.gpedro.integrations.slack.SlackMessage
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertDoesNotThrow
import org.mockito.kotlin.any
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.verifyNoInteractions
import org.mockito.kotlin.whenever
import org.springframework.core.task.SyncTaskExecutor
import org.springframework.core.task.TaskExecutor
import org.springframework.core.task.TaskRejectedException
import org.springframework.transaction.support.TransactionSynchronization
import org.springframework.transaction.support.TransactionSynchronizationManager

class SlackEventNotifierTest {

    private val notifier: SlackNotifier = mock()
    private val eventNotifier = SlackEventNotifier(notifier, SyncTaskExecutor())

    @Test
    fun `labels cannot ping channels or inject links`() {
        eventNotifier.send(
            SlackEvent(
                emoji = "🏷️",
                title = "Duty type created",
                headline = "<!channel> & <https://evil.example|click>",
                chips = listOf("<@U123>"),
            )
        )

        assertThat(capturedText()).isEqualTo(
            """
            *&lt;!channel&gt; &amp; &lt;https://evil.example|click&gt;*
            `&lt;@U123&gt;`
            """.trimIndent()
        )
    }

    @Test
    fun `labels cannot break the headline or chip wrapping`() {
        eventNotifier.send(
            SlackEvent(
                emoji = "🏷️",
                title = "Duty type created",
                headline = "night*shift `x`\nsecond line",
                chips = listOf("team`name", "/api/**"),
            )
        )

        assertThat(capturedText()).isEqualTo(
            """
            *night∗shift ˋxˋ second line*
            `teamˋname`  `/api/**`
            """.trimIndent()
        )
    }

    @Test
    fun `long labels are capped`() {
        eventNotifier.send(SlackEvent(emoji = "🏷️", title = "Duty type created", headline = "가".repeat(100)))

        assertThat(capturedText()).isEqualTo("*${"가".repeat(60)}… (+40 chars)*")
    }

    @Test
    fun `sendNow delivers on the calling thread even when the executor no longer accepts tasks`() {
        val closedExecutor = TaskExecutor { throw TaskRejectedException("executor shut down") }

        SlackEventNotifier(notifier, closedExecutor).sendNow(SlackEvent(emoji = "🔴", title = "Shutting down"))

        verify(notifier).call(any())
    }

    @Test
    fun `sendNow swallows delivery failures`() {
        whenever(notifier.call(any())).thenThrow(IllegalStateException("webhook down"))

        assertDoesNotThrow { eventNotifier.sendNow(SlackEvent(emoji = "🔴", title = "Shutting down")) }
    }

    @Test
    fun `sendAfterCommit waits for the transaction to commit`() {
        TransactionSynchronizationManager.initSynchronization()
        try {
            eventNotifier.sendAfterCommit(SlackEvent(emoji = "🏷️", title = "Duty type created"))
            verifyNoInteractions(notifier)

            TransactionSynchronizationManager.getSynchronizations().forEach(TransactionSynchronization::afterCommit)
        } finally {
            TransactionSynchronizationManager.clearSynchronization()
        }

        verify(notifier).call(any())
    }

    @Test
    fun `sendAfterCommit stays silent when the transaction rolls back`() {
        TransactionSynchronizationManager.initSynchronization()
        try {
            eventNotifier.sendAfterCommit(SlackEvent(emoji = "🏷️", title = "Duty type created"))

            TransactionSynchronizationManager.getSynchronizations().forEach {
                it.afterCompletion(TransactionSynchronization.STATUS_ROLLED_BACK)
            }
        } finally {
            TransactionSynchronizationManager.clearSynchronization()
        }

        verifyNoInteractions(notifier)
    }

    @Test
    fun `sendAfterCommit sends immediately outside a transaction`() {
        eventNotifier.sendAfterCommit(SlackEvent(emoji = "🏷️", title = "Duty type created"))

        verify(notifier).call(any())
    }

    @Test
    fun `sendAfterCommit does not fail the committed work when the executor rejects the alert`() {
        val closedExecutor = TaskExecutor { throw TaskRejectedException("executor shut down") }

        assertDoesNotThrow {
            SlackEventNotifier(notifier, closedExecutor).sendAfterCommit(SlackEvent(emoji = "🏷️", title = "Duty type created"))
        }
    }

    private fun capturedText(): String {
        val captor = argumentCaptor<SlackMessage>()
        verify(notifier).call(captor.capture())
        val attachment: JsonObject = captor.firstValue.prepare()["attachments"].asJsonArray.single().asJsonObject
        return attachment["text"].asString
    }
}
