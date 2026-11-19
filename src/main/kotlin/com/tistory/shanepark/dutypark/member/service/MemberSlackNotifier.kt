package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.common.slack.SlackEvent
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackEventNotifier
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import org.springframework.stereotype.Component

/**
 * 새 회원이 가입했다는 사실과 가입 경로만 알린다. 이름과 계정 식별자는 슬랙에 담지 않는다.
 */
@Component
class MemberSlackNotifier(
    private val slackEventNotifier: SlackEventNotifier,
) {

    fun ssoSignedUp(provider: SsoType) {
        slackEventNotifier.sendAfterCommit(
            SlackEvent(
                emoji = "👋",
                title = "New member",
                chips = listOf(provider.name),
            )
        )
    }
}
