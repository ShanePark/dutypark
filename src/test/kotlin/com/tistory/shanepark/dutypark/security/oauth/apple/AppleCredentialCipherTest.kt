package com.tistory.shanepark.dutypark.security.oauth.apple

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import java.util.Base64

class AppleCredentialCipherTest {
    @Test
    fun `encrypts refresh token at rest and decrypts it`() {
        val cipher = AppleCredentialCipher(Base64.getEncoder().encodeToString(ByteArray(32) { it.toByte() }))

        val encrypted = cipher.encrypt("sensitive-refresh-token")

        assertThat(encrypted).doesNotContain("sensitive-refresh-token")
        assertThat(cipher.decrypt(encrypted)).isEqualTo("sensitive-refresh-token")
        assertThat(cipher.encrypt("sensitive-refresh-token")).isNotEqualTo(encrypted)
    }

    @Test
    fun `blank encryption key keeps startup possible but fails on use`() {
        val cipher = AppleCredentialCipher("")

        val exception = assertThrows<AppleOAuthException> { cipher.encrypt("token") }
        assertThat(exception.message).isEqualTo("auth.apple.configurationUnavailable")
    }
}
