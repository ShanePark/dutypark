package com.tistory.shanepark.dutypark.report.service

import com.tistory.shanepark.dutypark.common.slack.SlackEvent
import com.tistory.shanepark.dutypark.common.slack.SlackEventLevel
import com.tistory.shanepark.dutypark.common.slack.SlackTextMasking
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackEventNotifier
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.report.domain.dto.CreateReportRequest
import com.tistory.shanepark.dutypark.report.domain.dto.ReportCreateResult
import com.tistory.shanepark.dutypark.report.domain.entity.ContentReport
import org.springframework.stereotype.Component

/**
 * 새 신고와 그 철회를 슬랙에서 바로 분류할 수 있을 만큼 담는다.
 * 중복 신고는 기존 접수 건에 묶이므로 방금 들어온 요청 기준으로 알리고, 색과 배지로 구분해 먼저 볼 것과 나눈다.
 * 신고 대상 콘텐츠 원문은 관리자 화면에서만 본다.
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
                subtitle = "${display(reporter)} → ${display(reported)}",
                headline = request.reason.name,
                chips = buildList {
                    add(request.targetType.name)
                    if (request.alsoBlock) add("also blocked")
                    if (!result.isNew) add("duplicate")
                },
                body = SlackTextMasking.preview(request.detail, DETAIL_PREVIEW_LENGTH)
                    .takeIf { it != SlackTextMasking.EMPTY },
                footnote = listOf(
                    result.id.toString().take(SHORT_ID_LENGTH),
                    "target ${request.targetId.take(SHORT_ID_LENGTH)}",
                ),
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
                subtitle = "${display(report.reporter, report.reporterName)} → " +
                    display(report.reportedMember, report.reportedMemberName),
                headline = report.reason.name,
                chips = listOf(report.targetType.name),
                body = SlackTextMasking.preview(report.detail, DETAIL_PREVIEW_LENGTH)
                    .takeIf { it != SlackTextMasking.EMPTY },
                footnote = listOf(
                    report.id.toString().take(SHORT_ID_LENGTH),
                    "target ${report.targetId.take(SHORT_ID_LENGTH)}",
                ),
                level = SlackEventLevel.MUTED,
            )
        )
    }

    private fun display(member: Member): String = "${member.name} (#${member.id})"

    /** 탈퇴한 계정은 참조가 끊어져 신고 시점 이름만 남는다. */
    private fun display(member: Member?, snapshotName: String): String = member?.let(::display) ?: snapshotName

    companion object {
        private const val DETAIL_PREVIEW_LENGTH = 300
        private const val SHORT_ID_LENGTH = 8
    }
}
