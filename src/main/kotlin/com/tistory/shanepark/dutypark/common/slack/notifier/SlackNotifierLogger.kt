package com.tistory.shanepark.dutypark.common.slack.notifier

import com.tistory.shanepark.dutypark.common.config.logger
import net.gpedro.integrations.slack.SlackMessage

class SlackNotifierLogger : SlackNotifier {

    private val log = logger()

    override fun call(slackMessage: SlackMessage) {
        log.info("SlackNotifierLogger: $slackMessage")
    }
}
