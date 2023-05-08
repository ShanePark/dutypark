package com.tistory.shanepark.dutypark.common.slack.notifier

import net.gpedro.integrations.slack.SlackApi
import net.gpedro.integrations.slack.SlackMessage

class SlackNotifierSender(private val slackApi: SlackApi) : SlackNotifier {

    override fun call(slackMessage: SlackMessage) {
        slackApi.call(slackMessage)
    }

}
