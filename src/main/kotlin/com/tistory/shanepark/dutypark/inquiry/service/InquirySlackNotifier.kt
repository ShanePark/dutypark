package com.tistory.shanepark.dutypark.inquiry.service

import com.tistory.shanepark.dutypark.common.slack.SlackEvent
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackEventNotifier
import com.tistory.shanepark.dutypark.inquiry.domain.entity.Inquiry
import org.springframework.stereotype.Component

/**
 * 새 문의가 접수되었다는 운영 신호만 슬랙으로 보낸다.
 * 문의에 포함될 수 있는 계정 정보, 회신 주소, 접속지, 제목과 본문은 외부 알림에 담지 않는다.
 */
@Component
class InquirySlackNotifier(
    private val slackEventNotifier: SlackEventNotifier,
) {

    fun inquiryCreated(inquiry: Inquiry) {
        slackEventNotifier.send(
            SlackEvent(
                emoji = "📩",
                title = "New inquiry",
                chips = listOf(if (inquiry.member == null) "GUEST" else "MEMBER"),
            )
        )
    }
}
