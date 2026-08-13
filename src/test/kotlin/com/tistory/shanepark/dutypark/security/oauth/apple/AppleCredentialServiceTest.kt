package com.tistory.shanepark.dutypark.security.oauth.apple

import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.mockito.kotlin.*
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset

class AppleCredentialServiceTest {
    private val repository: AppleOAuthCredentialRepository = mock()
    private val cipher: AppleCredentialCipher = mock()
    private val provider: AppleProviderClient = mock()
    private val secrets: AppleClientSecretFactory = mock()
    private val clock = Clock.fixed(Instant.parse("2026-08-13T00:00:00Z"), ZoneOffset.UTC)
    private val service = AppleCredentialService(repository, cipher, provider, secrets, clock)

    @Test
    fun `upsert stores only encrypted refresh token`() {
        whenever(repository.findByProviderAndSocialId(SsoType.APPLE, "subject")).thenReturn(null)
        whenever(cipher.encrypt("plain-refresh-token")).thenReturn("v1:iv:ciphertext")
        whenever(repository.save(any())).thenAnswer { it.arguments[0] }

        service.upsert("subject", "plain-refresh-token")

        val saved = argumentCaptor<AppleOAuthCredential>()
        verify(repository).save(saved.capture())
        assertThat(saved.firstValue.encryptedRefreshToken).isEqualTo("v1:iv:ciphertext")
        assertThat(saved.firstValue.encryptedRefreshToken).doesNotContain("plain-refresh-token")
    }

    @Test
    fun `revoke success deletes credential after provider call`() {
        val credential = credential()
        whenever(repository.findByProviderAndSocialId(SsoType.APPLE, "subject")).thenReturn(credential)
        whenever(cipher.decrypt(credential.encryptedRefreshToken)).thenReturn("refresh-token")
        whenever(secrets.clientId()).thenReturn("io.github.shanepark.dutypark")
        whenever(secrets.create()).thenReturn("client-secret")

        service.revokeAndDelete("subject")

        val order = inOrder(provider, repository)
        order.verify(provider).revoke("refresh-token", "io.github.shanepark.dutypark", "client-secret")
        order.verify(repository).delete(credential)
    }

    @Test
    fun `revoke failure keeps credential for retry`() {
        val credential = credential()
        whenever(repository.findByProviderAndSocialId(SsoType.APPLE, "subject")).thenReturn(credential)
        whenever(cipher.decrypt(credential.encryptedRefreshToken)).thenReturn("refresh-token")
        whenever(secrets.clientId()).thenReturn("io.github.shanepark.dutypark")
        whenever(secrets.create()).thenReturn("client-secret")
        whenever(provider.revoke(any(), any(), any()))
            .thenThrow(AppleOAuthException("auth.apple.provider.unavailable", 503))

        assertThrows<AppleOAuthException> { service.revokeAndDelete("subject") }

        verify(repository, never()).delete(any())
    }

    private fun credential() = AppleOAuthCredential(
        socialId = "subject",
        encryptedRefreshToken = "encrypted",
        createdAt = java.time.LocalDateTime.now(clock),
        updatedAt = java.time.LocalDateTime.now(clock),
    )
}
