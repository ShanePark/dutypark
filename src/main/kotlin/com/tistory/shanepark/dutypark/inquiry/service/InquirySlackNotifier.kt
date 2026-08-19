package com.tistory.shanepark.dutypark.inquiry.service

import com.tistory.shanepark.dutypark.common.slack.SlackEvent
import com.tistory.shanepark.dutypark.common.slack.SlackTextMasking
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackEventNotifier
import com.tistory.shanepark.dutypark.inquiry.domain.entity.Inquiry
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import org.springframework.stereotype.Component

/**
 * 새 문의를 슬랙에서 바로 판단할 수 있을 만큼 담는다.
 * 회신 주소와 접속지는 [SlackTextMasking] 을 거치고, 본문은 미리보기 길이까지만 내보낸다.
 * 접수 시각은 슬랙 메시지 시각과 같으므로 넣지 않는다.
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
                subtitle = author(inquiry.member),
                headline = SlackTextMasking.preview(inquiry.subject, SUBJECT_PREVIEW_LENGTH).takeIf(::isPresent),
                chips = listOf(
                    SlackTextMasking.maskEmail(inquiry.email),
                    SlackTextMasking.maskIp(inquiry.ipAddress),
                ).filter(::isPresent),
                body = SlackTextMasking.preview(inquiry.content, CONTENT_PREVIEW_LENGTH).takeIf(::isPresent),
                footnote = listOf(inquiry.id.toString().take(SHORT_ID_LENGTH)),
            )
        )
    }

    private fun author(member: Member?): String {
        return member?.let { "Member ${it.name} (#${it.id})" } ?: "Guest"
    }

    private fun isPresent(value: String) = value != SlackTextMasking.EMPTY

    companion object {
        private const val SUBJECT_PREVIEW_LENGTH = 100
        private const val CONTENT_PREVIEW_LENGTH = 300
        private const val SHORT_ID_LENGTH = 8
    }
}
