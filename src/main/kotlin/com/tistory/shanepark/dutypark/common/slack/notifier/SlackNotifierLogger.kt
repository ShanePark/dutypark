package com.tistory.shanepark.dutypark.common.slack.notifier

import com.tistory.shanepark.dutypark.common.config.logger
import net.gpedro.integrations.slack.SlackMessage

class SlackNotifierLogger : SlackNotifier {

    private val log = logger()

    override fun call(slackMessage: SlackMessage) {
        // Keep the no-token fallback from becoming another payload sink in local or shipped logs.
        log.info("Slack notification suppressed because no webhook is configured")
    }
}
