package com.tistory.shanepark.dutypark.common.listener

import com.tistory.shanepark.dutypark.security.domain.dto.UserAgentInfo
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class UserAgentAnalyzerWarmUpListenerTest {

    @Test
    fun `application ready builds the user agent analyzer in the background`() {
        val warmUpThread = UserAgentAnalyzerWarmUpListener().startWarmUp()

        assertThat(warmUpThread).isNotSameAs(Thread.currentThread())
        assertThat(warmUpThread.isDaemon).isTrue()
        warmUpThread.join(60_000)
        assertThat(UserAgentInfo.isAnalyzerInitialized()).isTrue()
    }
}
