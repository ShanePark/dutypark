package com.tistory.shanepark.dutypark.common.slack

import net.gpedro.integrations.slack.SlackApi
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration

@Configuration
class SlackApiConfiguration(
    @param:Value("\${dutypark.slack.token}")
    val slackToken: String
) {

    @Bean
    fun slackApi(): SlackApi {
        return SlackApi("https://hooks.slack.com/services/$slackToken")
    }

}
