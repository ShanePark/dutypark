package com.tistory.shanepark.dutypark.common.slack.notifier

import net.gpedro.integrations.slack.SlackApi
import net.gpedro.integrations.slack.SlackMessage
import org.junit.jupiter.api.Test
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify

class SlackNotifierTest {

    @Test
    fun `logger notifier does not throw`() {
        val notifier = SlackNotifierLogger()

        notifier.call(SlackMessage("test"))
    }

    @Test
    fun `sender notifier delegates to slack api`() {
        val slackApi = mock<SlackApi>()
        val notifier = SlackNotifierSender(slackApi)
        val message = SlackMessage("test")

        notifier.call(message)

        verify(slackApi).call(message)
    }
}
