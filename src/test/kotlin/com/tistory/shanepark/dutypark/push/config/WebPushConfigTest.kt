package com.tistory.shanepark.dutypark.push.config

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class WebPushConfigTest {

    @Test
    fun `pushService returns null when keys are blank`() {
        val config = configWithKeys("", "")

        val service = config.pushService()

        assertThat(service).isNull()
    }

    private fun configWithKeys(publicKey: String, privateKey: String): WebPushConfig {
        val config = WebPushConfig()
        setField(config, "publicKey", publicKey)
        setField(config, "privateKey", privateKey)
        return config
    }

    private fun setField(target: Any, name: String, value: String) {
        val field = target::class.java.getDeclaredField(name)
        field.isAccessible = true
        field.set(target, value)
    }
}
