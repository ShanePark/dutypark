package com.tistory.shanepark.dutypark.common.slack.notifier

import net.gpedro.integrations.slack.SlackMessage

class SlackNotifierLogger : SlackNotifier {

    private val log: org.slf4j.Logger = org.slf4j.LoggerFactory.getLogger(this.javaClass)

    override fun call(slackMessage: SlackMessage) {
        log.info("SlackNotifierLogger: $slackMessage")
    }
}
