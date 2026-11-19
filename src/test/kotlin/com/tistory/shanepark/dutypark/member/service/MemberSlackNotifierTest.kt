package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.common.slack.SlackEventLevel
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackEventNotifier
import com.tistory.shanepark.dutypark.common.slack.notifier.SlackNotifier
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import net.gpedro.integrations.slack.SlackMessage
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.springframework.core.task.SyncTaskExecutor

class MemberSlackNotifierTest {

    private val notifier: SlackNotifier = mock()

    @Test
    fun `sso signup shows only the provider`() {
        MemberSlackNotifier(SlackEventNotifier(notifier, SyncTaskExecutor())).ssoSignedUp(SsoType.KAKAO)

        val captor = argumentCaptor<SlackMessage>()
        verify(notifier).call(captor.capture())
        val attachment = captor.firstValue.prepare()["attachments"].asJsonArray.single().asJsonObject
        assertThat(attachment["title"].asString).isEqualTo("👋 New member")
        assertThat(attachment["text"].asString).isEqualTo("`KAKAO`")
        assertThat(attachment["color"].asString).isEqualTo(SlackEventLevel.INFO.color)
    }
}
