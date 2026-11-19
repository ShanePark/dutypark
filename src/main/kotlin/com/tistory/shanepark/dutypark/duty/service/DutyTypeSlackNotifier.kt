package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.common.slack.SlackEvent
import com.tistory.shanepark.dutypark.common.slack.SlackEventLevel
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackEventNotifier
import org.springframework.stereotype.Component

/**
 * 팀 관리자가 근무 유형을 바꾼 일을 팀 이름과 근무 유형 이름으로 알린다.
 * 누가 바꿨는지와 팀·근무 유형 ID 는 감사 로그에만 남긴다. 롤백된 변경은 알리지 않도록 커밋 뒤에 보낸다.
 */
@Component
class DutyTypeSlackNotifier(
    private val slackEventNotifier: SlackEventNotifier,
) {

    fun created(teamName: String, dutyTypeName: String) {
        slackEventNotifier.sendAfterCommit(
            SlackEvent(
                emoji = "🏷️",
                title = "Duty type created",
                headline = dutyTypeName,
                chips = listOf(teamName),
            )
        )
    }

    fun updated(teamName: String, beforeName: String, afterName: String) {
        slackEventNotifier.sendAfterCommit(
            SlackEvent(
                emoji = "✏️",
                title = "Duty type updated",
                headline = if (beforeName == afterName) afterName else "$beforeName → $afterName",
                chips = listOf(teamName),
                level = SlackEventLevel.MUTED,
            )
        )
    }

    fun visibilityChanged(teamName: String, dutyTypeName: String, hidden: Boolean) {
        slackEventNotifier.sendAfterCommit(
            SlackEvent(
                emoji = if (hidden) "🙈" else "👁️",
                title = if (hidden) "Duty type hidden" else "Duty type shown",
                headline = dutyTypeName,
                chips = listOf(teamName),
                level = SlackEventLevel.MUTED,
            )
        )
    }
}
