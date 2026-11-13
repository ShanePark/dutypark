package com.tistory.shanepark.dutypark.holiday.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.slack.SlackEvent
import com.tistory.shanepark.dutypark.common.slack.SlackEventLevel
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackEventNotifier
import org.springframework.stereotype.Component

/**
 * 공휴일 API 조회 실패를 슬랙으로 알린다.
 * 예외 메시지와 stack trace 에는 요청 URL 과 서비스 키가 담길 수 있어 연도와 예외 클래스명만 보낸다.
 */
@Component
class HolidaySlackNotifier(
    private val slackEventNotifier: SlackEventNotifier,
) {
    private val log = logger()

    fun fetchFailed(year: Int, error: Exception) {
        try {
            slackEventNotifier.send(
                SlackEvent(
                    emoji = "⚠️",
                    title = "Holiday API fetch failed",
                    headline = error.javaClass.simpleName.ifEmpty { error.javaClass.name },
                    chips = listOf(year.toString()),
                    level = SlackEventLevel.ALERT,
                )
            )
        } catch (notificationFailure: Exception) {
            log.error(
                "Failed to send Slack notification (exception={})",
                notificationFailure.javaClass.name,
            )
        }
    }
}
