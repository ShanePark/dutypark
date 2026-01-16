package com.tistory.shanepark.dutypark.common.slack

import com.tistory.shanepark.dutypark.common.slack.notifier.SlackNotifierLogger
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackNotifierSender
import net.gpedro.integrations.slack.SlackMessage
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class SlackApiConfigurationTest {

    @Test
    fun `slackNotifier returns logger when token is blank`() {
        val config = SlackApiConfiguration("")

        val notifier = config.slackNotifier()

        assertThat(notifier).isInstanceOf(SlackNotifierLogger::class.java)
    }

    @Test
    fun `slackNotifier returns sender when token is present`() {
        val config = SlackApiConfiguration("token")

        val notifier = config.slackNotifier()

        assertThat(notifier).isInstanceOf(SlackNotifierSender::class.java)
    }

    @Test
    fun `threadPoolTaskExecutor configures pool sizes`() {
        val config = SlackApiConfiguration("token")

        val executor = config.threadPoolTaskExecutor() as org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor

        assertThat(executor.corePoolSize).isEqualTo(1)
        assertThat(executor.maxPoolSize).isEqualTo(3)
    }

    @Test
    fun `dummySlackNotifier ignores messages`() {
        val config = SlackApiConfiguration("token")
        val notifier = config.dummySlackNotifier()

        notifier.call(SlackMessage("test"))
    }
}
