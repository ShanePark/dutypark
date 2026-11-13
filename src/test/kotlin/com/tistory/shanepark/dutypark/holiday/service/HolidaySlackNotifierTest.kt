package com.tistory.shanepark.dutypark.holiday.service

import ch.qos.logback.classic.Logger
import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.core.read.ListAppender
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackEventNotifier
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackNotifier
import net.gpedro.integrations.slack.SlackMessage
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.verifyNoInteractions
import org.slf4j.LoggerFactory
import org.springframework.core.task.SyncTaskExecutor
import org.springframework.core.task.TaskExecutor
import org.springframework.core.task.TaskRejectedException

class HolidaySlackNotifierTest {

    private val notifier: SlackNotifier = mock()

    @Test
    fun `fetch failure alert carries only the year and exception type`() {
        val error = IllegalStateException("https://apis.data.go.kr/?serviceKey=secret-key")

        HolidaySlackNotifier(SlackEventNotifier(notifier, SyncTaskExecutor())).fetchFailed(2029, error)

        val messageCaptor = argumentCaptor<SlackMessage>()
        verify(notifier).call(messageCaptor.capture())
        val payload = messageCaptor.firstValue.prepare().toString()
        assertThat(payload).contains("Holiday API fetch failed", "2029", "IllegalStateException")
            .doesNotContain("secret-key", "serviceKey", "apis.data.go.kr", "HolidayService")
    }

    @Test
    fun `a Slack submission failure does not escape the holiday lookup`() {
        val executor = TaskExecutor { throw TaskRejectedException("secret-rejection") }
        val logger = LoggerFactory.getLogger(HolidaySlackNotifier::class.java) as Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try {
            HolidaySlackNotifier(SlackEventNotifier(notifier, executor))
                .fetchFailed(2029, IllegalStateException("upstream failure"))
        } finally {
            logger.detachAppender(appender)
        }

        verifyNoInteractions(notifier)
        assertThat(appender.list).hasSize(1)
        assertThat(appender.list.single().formattedMessage).contains("TaskRejectedException")
            .doesNotContain("secret-rejection", "upstream failure")
    }
}
