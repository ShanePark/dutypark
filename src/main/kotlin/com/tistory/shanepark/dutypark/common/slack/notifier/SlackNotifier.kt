package com.tistory.shanepark.dutypark.common.slack.notifier

import net.gpedro.integrations.slack.SlackMessage

interface SlackNotifier {
    fun call(slackMessage: SlackMessage)
}
