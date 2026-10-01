package com.tistory.shanepark.dutypark.security.oauth.web

import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.security.oauth.OAuthWebBaseUrl
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.mockito.kotlin.mock
import org.springframework.mock.web.MockHttpServletRequest
import java.time.Clock

class WebOAuthAuditTest {
    @Test
    fun `callback missing browser session logs safe provider and reason`() {
        val service = WebOAuthService(mock(), Clock.systemUTC(), mock<OAuthWebBaseUrl>(), mock(), "kakao", "naver")
        val logger = org.slf4j.LoggerFactory.getLogger(WebOAuthService::class.java) as ch.qos.logback.classic.Logger
        val appender = ch.qos.logback.core.read.ListAppender<ch.qos.logback.classic.spi.ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try {
            assertThrows<WebOAuthStateException> {
                service.claim(SsoType.KAKAO, "private-state", null, MockHttpServletRequest())
            }
            assertThat(appender.list.single().formattedMessage)
                .contains("auth.oauth.web.denied", "KAKAO", "browser_session_missing")
                .doesNotContain("private-state")
        } finally {
            logger.detachAppender(appender)
            appender.stop()
        }
    }
}
