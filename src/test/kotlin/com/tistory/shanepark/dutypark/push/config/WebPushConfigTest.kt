package com.tistory.shanepark.dutypark.push.config

import nl.martijndwars.webpush.Encoding
import nl.martijndwars.webpush.Notification
import nl.martijndwars.webpush.Utils
import org.bouncycastle.jce.interfaces.ECPrivateKey
import org.bouncycastle.jce.interfaces.ECPublicKey
import java.security.KeyPairGenerator
import java.security.spec.ECGenParameterSpec
import java.util.Base64
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class WebPushConfigTest {

    @Test
    fun `pushService returns null when keys are blank`() {
        val config = configWithKeys("", "")

        val service = config.pushService()

        assertThat(service).isNull()
    }

    @Test
    fun `enabled push service disables redirects for both notification encodings`() {
        WebPushConfig() // Registers the existing BouncyCastle provider.
        val generator = KeyPairGenerator.getInstance("EC", "BC")
        generator.initialize(ECGenParameterSpec("secp256r1"))
        val keys = generator.generateKeyPair()
        val encoder = Base64.getUrlEncoder().withoutPadding()
        val config = configWithKeys(
            encoder.encodeToString(Utils.encode(keys.public as ECPublicKey)),
            encoder.encodeToString(Utils.encode(keys.private as ECPrivateKey)),
        )
        val service = requireNotNull(config.pushService())
        val notification = Notification("https://fcm.googleapis.com/token", keys.public, ByteArray(16), "{}".toByteArray())
        Encoding.values().forEach { encoding ->
            val request = service.preparePost(notification, encoding)
            assertThat(request.config.isRedirectsEnabled).isFalse
            assertThat(request.uri.toString()).isEqualTo(notification.endpoint)
        }
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
