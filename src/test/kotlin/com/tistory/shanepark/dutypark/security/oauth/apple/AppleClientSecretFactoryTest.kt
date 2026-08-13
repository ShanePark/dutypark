package com.tistory.shanepark.dutypark.security.oauth.apple

import io.jsonwebtoken.Jwts
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import java.security.KeyPairGenerator
import java.security.spec.ECGenParameterSpec
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import java.util.Base64

class AppleClientSecretFactoryTest {
    private val now = Instant.parse("2026-08-13T00:00:00Z")
    private val clock = Clock.fixed(now, ZoneOffset.UTC)

    @Test
    fun `creates short lived ES256 Apple client secret from p8 key`() {
        val keyPair = KeyPairGenerator.getInstance("EC").apply {
            initialize(ECGenParameterSpec("secp256r1"))
        }.generateKeyPair()
        val pem = "-----BEGIN PRIVATE KEY-----\n" +
            Base64.getMimeEncoder(64, "\n".toByteArray()).encodeToString(keyPair.private.encoded) +
            "\n-----END PRIVATE KEY-----"
        val factory = AppleClientSecretFactory(clock, CLIENT_ID, "TEAM123", "KEY123", pem)

        val jwt = Jwts.parser()
            .verifyWith(keyPair.public)
            .clock { java.util.Date.from(now) }
            .build()
            .parseSignedClaims(factory.create())

        assertThat(jwt.header.algorithm).isEqualTo("ES256")
        assertThat(jwt.header.keyId).isEqualTo("KEY123")
        assertThat(jwt.payload.issuer).isEqualTo("TEAM123")
        assertThat(jwt.payload.subject).isEqualTo(CLIENT_ID)
        assertThat(jwt.payload.audience).containsExactly("https://appleid.apple.com")
        assertThat(jwt.payload.expiration.toInstant()).isEqualTo(now.plusSeconds(600))
    }

    @Test
    fun `blank Apple signing configuration is unavailable only when used`() {
        val factory = AppleClientSecretFactory(clock, "", "", "", "")

        val exception = assertThrows<AppleOAuthException> { factory.create() }

        assertThat(exception.message).isEqualTo("auth.apple.configurationUnavailable")
    }

    companion object {
        private const val CLIENT_ID = "io.github.shanepark.dutypark"
    }
}
