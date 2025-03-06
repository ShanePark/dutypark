package com.tistory.shanepark.dutypark.common.slack

import com.tistory.shanepark.dutypark.common.slack.notifier.SlackNotifier
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackNotifierLogger
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackNotifierSender
import net.gpedro.integrations.slack.SlackApi
import net.gpedro.integrations.slack.SlackMessage
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.context.annotation.Profile
import org.springframework.core.task.TaskExecutor
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor

@Configuration
class SlackApiConfiguration(
    @param:Value("\${dutypark.slack.token}")
    val slackToken: String
) {

    private val log: Logger = LoggerFactory.getLogger(this.javaClass)

    @Bean("slackTaskExecutor")
    fun threadPoolTaskExecutor(): TaskExecutor {
        val executor = ThreadPoolTaskExecutor()
        executor.corePoolSize = 1
        executor.maxPoolSize = 3
        executor.initialize()
        return executor
    }

    @Bean
    @Profile("op")
    fun slackNotifierProd(): SlackNotifier {
        log.info("Slack API registered. slackToken = ${slackToken}")
        val slackApi = SlackApi("https://hooks.slack.com/services/$slackToken")
        return SlackNotifierSender(slackApi)
    }

    @Bean
    @Profile("dev")
    fun slackNotifierDev(): SlackNotifier {
        log.info("Slack Notifier Logger registered.")
        return SlackNotifierLogger()
    }

    @Bean
    @Profile("!op && !dev")
    fun dummySlackNotifier(): SlackNotifier {
        log.info("Dummy Slack Notifier registered.")
        return object : SlackNotifier {
            override fun call(slackMessage: SlackMessage) {
                // do nothing
            }
        }
    }

}
