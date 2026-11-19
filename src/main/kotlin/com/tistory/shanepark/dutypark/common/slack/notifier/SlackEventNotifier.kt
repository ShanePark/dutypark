package com.tistory.shanepark.dutypark.common.slack.notifier

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.logging.auditContext
import org.slf4j.MDC
import com.tistory.shanepark.dutypark.common.slack.SlackEvent
import com.tistory.shanepark.dutypark.common.slack.SlackTextMasking
import net.gpedro.integrations.slack.SlackAttachment
import net.gpedro.integrations.slack.SlackMessage
import org.springframework.beans.factory.annotation.Qualifier
import org.springframework.core.task.TaskExecutor
import org.springframework.stereotype.Component
import org.springframework.transaction.support.TransactionSynchronization
import org.springframework.transaction.support.TransactionSynchronizationManager

/**
 * [SlackEvent] 를 슬랙 메시지 한 덩어리로 그린다.
 *
 * 제목과 운영 신호를 첨부 하나에 담아 색 막대 안에서 끝나게 하고, 메시지 본문은 비워 둔다.
 * 같은 문구가 첨부 위아래로 두 번 나오면 그만큼 세로로 길어지기 때문이다.
 *
 * headline 과 chips 에는 팀 이름처럼 사용자가 정한 라벨이 들어올 수 있으므로 그릴 때 한곳에서 길이를 자르고
 * 슬랙 제어 문자를 이스케이프한다. 이름이 `<!channel>` 이어도 멘션이나 링크가 되지 않고 굵게·코드 표시도 깨지지 않는다.
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
        val message = render(event)
        val requestId = MDC.get("requestId")
        try {
            taskExecutor.execute { deliver(message, event, requestId) }
        } catch (failure: Exception) {
            log.error(
                "Slack notification submission failed: {}",
                auditContext(mapOf("exceptionType" to failure.javaClass.name, "level" to event.level)),
            )
            throw failure
        }
    }

    /**
     * 트랜잭션 안에서 부르면 커밋된 뒤에만 보낸다. 롤백된 변경을 알리지 않기 위해서다.
     * 커밋된 작업이 알림 접수 실패로 오류 응답이 되지 않도록 접수 실패는 [send] 의 로그로만 남긴다.
     */
    fun sendAfterCommit(event: SlackEvent) {
        if (!TransactionSynchronizationManager.isSynchronizationActive()) {
            runCatching { send(event) }
            return
        }
        TransactionSynchronizationManager.registerSynchronization(
            object : TransactionSynchronization {
                override fun afterCommit() {
                    runCatching { send(event) }
                }
            }
        )
    }

    /**
     * 호출한 스레드에서 바로 보낸다. 컨텍스트가 닫히는 중에는 [taskExecutor] 가 먼저 새 작업을 거절할 수 있어
     * 종료 알림처럼 그 시점에 나가야 하는 알림에만 쓴다.
     */
    fun sendNow(event: SlackEvent) {
        deliver(render(event), event, MDC.get("requestId"))
    }

    private fun deliver(message: SlackMessage, event: SlackEvent, requestId: String?) {
        runCatching { slackNotifier.call(message) }
            .onFailure { failure ->
                log.error(
                    "Slack notification delivery failed: {}",
                    auditContext(mapOf("exceptionType" to failure.javaClass.name,
                        "level" to event.level, "requestId" to requestId)),
                )
            }
    }

    private fun render(event: SlackEvent): SlackMessage {
        val heading = "${event.emoji} ${event.title}"

        val attachment = SlackAttachment()
        attachment.setFallback(heading)
        attachment.setColor(event.level.color)
        attachment.setTitle(heading)
        attachment.addMarkdownAttribute("text")
        detail(event)?.let { attachment.setText(it) }

        val message = SlackMessage()
        message.setAttachments(listOf(attachment))
        message.setIcon(BOT_ICON)
        message.setText("")
        message.setUsername("DutyPark")
        return message
    }

    private fun detail(event: SlackEvent): String? {
        val lines = mutableListOf<String>()
        event.headline?.let { lines += "*${label(it).replace('*', BOLD_SAFE_ASTERISK)}*" }
        event.chips.takeIf { it.isNotEmpty() }?.let { chips ->
            lines += chips.joinToString(CHIP_GAP) { "`${label(it)}`" }
        }
        return lines.takeIf { it.isNotEmpty() }?.joinToString("\n")
    }

    /**
     * 한 줄로 접고 길이를 자른 뒤 슬랙이 요구하는 `&`, `<`, `>` 이스케이프를 한다.
     * 백틱은 코드 표시를 닫아 버리므로 닮은 문자로 바꾼다. 슬랙 mrkdwn 에는 백슬래시 이스케이프가 없다.
     */
    private fun label(text: String): String =
        SlackTextMasking.preview(text.replace(WHITESPACE, " "), MAX_LABEL_LENGTH)
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace('`', CODE_SAFE_BACKTICK)

    companion object {
        private const val CHIP_GAP = "  "
        private const val BOT_ICON = ":calendar:"
        private const val MAX_LABEL_LENGTH = 60
        private const val BOLD_SAFE_ASTERISK = '∗'
        private const val CODE_SAFE_BACKTICK = 'ˋ'
        private val WHITESPACE = Regex("\\s+")
    }
}
