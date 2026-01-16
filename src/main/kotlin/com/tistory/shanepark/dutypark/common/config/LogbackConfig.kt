package com.tistory.shanepark.dutypark.common.config

import ch.qos.logback.classic.Level
import ch.qos.logback.classic.LoggerContext
import ch.qos.logback.classic.encoder.PatternLayoutEncoder
import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.core.rolling.RollingFileAppender
import ch.qos.logback.core.rolling.TimeBasedRollingPolicy
import jakarta.annotation.PostConstruct
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Configuration

inline fun <reified T> T.logger(): Logger = LoggerFactory.getLogger(T::class.java)

@Configuration
class LogbackConfig(
    @param:Value("\${dutypark.log.path}") private val logPath: String
) {
    private val log = logger()

    @PostConstruct
    fun configureLogging() {
        val loggerContext = LoggerFactory.getILoggerFactory() as LoggerContext

        val encoder = PatternLayoutEncoder().apply {
            context = loggerContext
            pattern = "%d{yyyy-MM-dd HH:mm:ss} [%thread] %-5level %logger{36} - %msg%n"
            start()
        }

        val fileAppender = RollingFileAppender<ILoggingEvent>().apply {
            context = loggerContext
            name = "FILE"
            this.encoder = encoder
            isAppend = true
        }

        val rollingPolicy = TimeBasedRollingPolicy<ILoggingEvent>().apply {
            context = loggerContext
            fileNamePattern = "${logPath}/dutypark-%d{yyyy-MM-dd}.log"
            maxHistory = 365
            setParent(fileAppender)
            start()
        }

        fileAppender.rollingPolicy = rollingPolicy
        fileAppender.start()

        val rootLogger = loggerContext.getLogger("ROOT")
        rootLogger.level = Level.INFO
        rootLogger.addAppender(fileAppender)

        log.info("Log file path configured: {}", logPath)
    }
}
