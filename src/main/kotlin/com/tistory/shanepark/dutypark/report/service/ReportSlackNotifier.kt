package com.tistory.shanepark.dutypark.report.service

import com.tistory.shanepark.dutypark.common.slack.SlackEvent
import com.tistory.shanepark.dutypark.common.slack.SlackEventLevel
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackEventNotifier
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.report.domain.dto.CreateReportRequest
import com.tistory.shanepark.dutypark.report.domain.dto.ReportCreateResult
import com.tistory.shanepark.dutypark.report.domain.entity.ContentReport
import org.springframework.stereotype.Component

/**
 * 새 신고와 그 철회가 발생했다는 운영 신호만 슬랙으로 보낸다.
 * 신고 당사자, 대상 식별자, 신고 상세와 대상 콘텐츠는 관리자 화면에서만 본다.
 */
@Component
class ReportSlackNotifier(
    private val slackEventNotifier: SlackEventNotifier,
) {

    fun reportCreated(
        result: ReportCreateResult,
        reporter: Member,
        reported: Member,
        request: CreateReportRequest,
    ) {
        slackEventNotifier.send(
            SlackEvent(
                emoji = "🚨",
                title = "New report",
                headline = request.reason.name,
                chips = buildList {
                    add(request.targetType.name)
                    if (request.alsoBlock) add("also blocked")
                    if (!result.isNew) add("duplicate")
                },
                level = if (result.isNew) SlackEventLevel.NOTICE else SlackEventLevel.MUTED,
            )
        )
    }

    /**
     * 대기열에 있던 신고가 신고자 손으로 내려갔다는 기록. 처리할 일이 줄어드는 쪽이라 눈에 띄게 하지 않는다.
     */
    fun reportCanceled(report: ContentReport) {
        slackEventNotifier.send(
            SlackEvent(
                emoji = "↩️",
                title = "Report canceled",
                headline = report.reason.name,
                chips = listOf(report.targetType.name),
                level = SlackEventLevel.MUTED,
            )
        )
    }
}
