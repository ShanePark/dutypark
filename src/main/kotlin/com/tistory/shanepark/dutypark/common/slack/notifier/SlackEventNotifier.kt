package com.tistory.shanepark.dutypark.common.slack.notifier

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.slack.SlackEvent
import net.gpedro.integrations.slack.SlackAttachment
import net.gpedro.integrations.slack.SlackMessage
import org.springframework.beans.factory.annotation.Qualifier
import org.springframework.core.task.TaskExecutor
import org.springframework.stereotype.Component

/**
 * [SlackEvent] 를 슬랙 메시지 한 덩어리로 그린다.
 *
 * 제목·본문·각주를 첨부 하나에 담아 색 막대 안에서 끝나게 하고, 메시지 본문은 비워 둔다.
 * 같은 문구가 첨부 위아래로 두 번 나오면 그만큼 세로로 길어지기 때문이다.
 *
 * 전송은 요청 스레드를 붙잡지 않도록 전용 executor 로 넘기고, 알림 실패가 원래 작업에 번지지 않게 로그로만 남긴다.
 */
@Component
class SlackEventNotifier(
    private val slackNotifier: SlackNotifier,
    @param:Qualifier("slackTaskExecutor")
    private val taskExecutor: TaskExecutor,
) {
    private val log = logger()

    fun send(event: SlackEvent) {
        val heading = listOfNotNull("${event.emoji} ${event.title}", event.subtitle).joinToString(SEPARATOR)

        val attachment = SlackAttachment()
        attachment.setFallback(heading)
        attachment.setColor(event.level.color)
        attachment.setTitle(heading)
        attachment.addMarkdownAttribute("text")
        detail(event)?.let { attachment.setText(it) }
        event.footnote.takeIf { it.isNotEmpty() }?.let { attachment.setFooter(it.joinToString(SEPARATOR)) }

        val message = SlackMessage()
        message.setAttachments(listOf(attachment))
        message.setIcon(BOT_ICON)
        message.setText("")
        message.setUsername("DutyPark")

        taskExecutor.execute {
            runCatching { slackNotifier.call(message) }
                .onFailure { log.error("Failed to send Slack notification: {}", heading, it) }
        }
    }

    private fun detail(event: SlackEvent): String? {
        val lines = mutableListOf<String>()
        event.headline?.let { lines += "*$it*" }
        event.chips.takeIf { it.isNotEmpty() }?.let { chips ->
            lines += chips.joinToString(CHIP_GAP) { "`$it`" }
        }
        event.body?.let { body ->
            lines += body.lineSequence().joinToString("\n") { "> $it" }
        }
        return lines.takeIf { it.isNotEmpty() }?.joinToString("\n")
    }

    companion object {
        private const val SEPARATOR = "  ·  "
        private const val CHIP_GAP = "  "
        private const val BOT_ICON = ":calendar:"
    }
}
