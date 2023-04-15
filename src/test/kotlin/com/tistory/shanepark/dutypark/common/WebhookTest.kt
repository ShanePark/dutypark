package com.tistory.shanepark.dutypark.common

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import net.gpedro.integrations.slack.SlackApi
import net.gpedro.integrations.slack.SlackMessage
import org.junit.jupiter.api.Disabled
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Value

@Disabled("token is required")
class WebhookTest : DutyparkIntegrationTest() {

    @Value("\${dutypark.slack.token}")
    lateinit var token: String

    @Test
    @DisplayName("Slack Webhook Test")
    fun test() {
        val api = SlackApi("https://hooks.slack.com/services/$token")
        api.call(SlackMessage("Hello SpringBoot Test!"))
    }

}
