package com.tistory.shanepark.dutypark.duty.service

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

class DutyTypeSlackNotifierTest {

    private val notifier: SlackNotifier = mock()
    private val dutyTypeSlackNotifier = DutyTypeSlackNotifier(SlackEventNotifier(notifier, SyncTaskExecutor()))

    @Test
    fun `created shows the duty type and its team`() {
        dutyTypeSlackNotifier.created(teamName = "응급실", dutyTypeName = "야간")

        val attachment = capturedAttachment()
        assertThat(attachment["title"].asString).isEqualTo("🏷️ Duty type created")
        assertThat(attachment["text"].asString).isEqualTo("*야간*\n`응급실`")
        assertThat(attachment["color"].asString).isEqualTo(SlackEventLevel.INFO.color)
    }

    @Test
    fun `update without rename shows the current name`() {
        dutyTypeSlackNotifier.updated(teamName = "응급실", beforeName = "야간", afterName = "야간")

        val attachment = capturedAttachment()
        assertThat(attachment["title"].asString).isEqualTo("✏️ Duty type updated")
        assertThat(attachment["text"].asString).isEqualTo("*야간*\n`응급실`")
        assertThat(attachment["color"].asString).isEqualTo(SlackEventLevel.MUTED.color)
    }

    @Test
    fun `rename shows the old and new names`() {
        dutyTypeSlackNotifier.updated(teamName = "응급실", beforeName = "야간", afterName = "나이트")

        assertThat(capturedAttachment()["text"].asString).isEqualTo("*야간 → 나이트*\n`응급실`")
    }

    @Test
    fun `hiding and showing are told apart`() {
        dutyTypeSlackNotifier.visibilityChanged(teamName = "응급실", dutyTypeName = "야간", hidden = true)
        dutyTypeSlackNotifier.visibilityChanged(teamName = "응급실", dutyTypeName = "야간", hidden = false)

        val captor = argumentCaptor<SlackMessage>()
        verify(notifier, org.mockito.kotlin.times(2)).call(captor.capture())
        val (hidden, shown) = captor.allValues.map(::attachmentOf)
        assertThat(hidden["title"].asString).isEqualTo("🙈 Duty type hidden")
        assertThat(shown["title"].asString).isEqualTo("👁️ Duty type shown")
        listOf(hidden, shown).forEach {
            assertThat(it["text"].asString).isEqualTo("*야간*\n`응급실`")
            assertThat(it["color"].asString).isEqualTo(SlackEventLevel.MUTED.color)
        }
    }

    private fun capturedAttachment(): JsonObject {
        val captor = argumentCaptor<SlackMessage>()
        verify(notifier).call(captor.capture())
        return attachmentOf(captor.firstValue)
    }

    private fun attachmentOf(message: SlackMessage): JsonObject =
        message.prepare()["attachments"].asJsonArray.single().asJsonObject
}
