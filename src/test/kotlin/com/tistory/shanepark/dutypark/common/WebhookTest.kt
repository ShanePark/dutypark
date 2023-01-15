package com.tistory.shanepark.dutypark.common

import net.gpedro.integrations.slack.SlackApi
import net.gpedro.integrations.slack.SlackMessage
import org.junit.jupiter.api.Disabled
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.test.context.ActiveProfiles

@SpringBootTest
@ActiveProfiles("dev")
@Disabled("token is required")
class WebhookTest {

    @Value("\${dutypark.slack.token}")
    lateinit var token: String

    @Test
    @DisplayName("Slack Webhook Test")
    fun test() {
        val api = SlackApi("https://hooks.slack.com/services/$token")
        api.call(SlackMessage("Hello SpringBoot Test!"))
    }

}
