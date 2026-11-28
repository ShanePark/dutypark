package com.tistory.shanepark.dutypark.common.listener

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.security.domain.dto.UserAgentInfo
import org.springframework.boot.context.event.ApplicationReadyEvent
import org.springframework.context.event.EventListener
import org.springframework.stereotype.Component
import kotlin.concurrent.thread

/** Builds the user agent analyzer off the request path so the first session list request does not pay for it. */
@Component
class UserAgentAnalyzerWarmUpListener {

    private val log = logger()

    @EventListener(ApplicationReadyEvent::class)
    fun onApplicationReady() {
        startWarmUp()
    }

    internal fun startWarmUp(): Thread = thread(name = "user-agent-warm-up", isDaemon = true) {
        try {
            UserAgentInfo.warmUp()
        } catch (e: Exception) {
            log.warn("User agent analyzer warm-up failed; it will be built on first use", e)
        }
    }
}
