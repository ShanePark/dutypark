package com.tistory.shanepark.dutypark.security.oauth.apple

import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.mockito.kotlin.any
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.inOrder
import org.mockito.kotlin.mock
import org.mockito.kotlin.never
import org.mockito.kotlin.times
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.springframework.transaction.annotation.Propagation
import org.springframework.transaction.annotation.Transactional
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
    fun `upsert stores only encrypted refresh token for the selected client`() {
        whenever(
            repository.findByProviderAndSocialIdAndClientId(SsoType.APPLE, "subject", WEB_CLIENT_ID)
        ).thenReturn(null)
        whenever(cipher.encrypt("plain-refresh-token")).thenReturn("v1:iv:ciphertext")
        whenever(repository.saveAndFlush(any())).thenAnswer { it.arguments[0] }

        service.upsert("subject", "plain-refresh-token", WEB_CLIENT_ID)

        val saved = argumentCaptor<AppleOAuthCredential>()
        verify(repository).saveAndFlush(saved.capture())
        assertThat(saved.firstValue.encryptedRefreshToken).isEqualTo("v1:iv:ciphertext")
        assertThat(saved.firstValue.encryptedRefreshToken).doesNotContain("plain-refresh-token")
        assertThat(saved.firstValue.clientId).isEqualTo(WEB_CLIENT_ID)
    }

    @Test
    fun `native and web upserts preserve both client grants`() {
        whenever(repository.findByProviderAndSocialIdAndClientId(SsoType.APPLE, "subject", NATIVE_CLIENT_ID))
            .thenReturn(null)
        whenever(repository.findByProviderAndSocialIdAndClientId(SsoType.APPLE, "subject", WEB_CLIENT_ID))
            .thenReturn(null)
        whenever(secrets.isNativeClientId(NATIVE_CLIENT_ID)).thenReturn(true)
        whenever(cipher.encrypt("native-refresh")).thenReturn("native-encrypted")
        whenever(cipher.encrypt("web-refresh")).thenReturn("web-encrypted")
        whenever(repository.saveAndFlush(any())).thenAnswer { it.arguments[0] }

        service.upsert("subject", "native-refresh", NATIVE_CLIENT_ID)
        service.upsert("subject", "web-refresh", WEB_CLIENT_ID)

        val saved = argumentCaptor<AppleOAuthCredential>()
        verify(repository, times(2)).saveAndFlush(saved.capture())
        assertThat(saved.allValues.map { it.clientId }).containsExactly(NATIVE_CLIENT_ID, WEB_CLIENT_ID)
        assertThat(saved.allValues.map { it.encryptedRefreshToken })
            .containsExactly("native-encrypted", "web-encrypted")
    }

    @Test
    fun `native upsert backfills client id on an existing legacy credential`() {
        val legacy = credential(clientId = null)
        whenever(
            repository.findByProviderAndSocialIdAndClientId(SsoType.APPLE, "subject", NATIVE_CLIENT_ID)
        ).thenReturn(null)
        whenever(secrets.isNativeClientId(NATIVE_CLIENT_ID)).thenReturn(true)
        whenever(repository.findByProviderAndSocialIdAndClientIdIsNull(SsoType.APPLE, "subject"))
            .thenReturn(legacy)
        whenever(cipher.encrypt("new-refresh-token")).thenReturn("new-encrypted-token")

        service.upsert("subject", "new-refresh-token", NATIVE_CLIENT_ID)

        assertThat(legacy.clientId).isEqualTo(NATIVE_CLIENT_ID)
        assertThat(legacy.encryptedRefreshToken).isEqualTo("new-encrypted-token")
        verify(repository, never()).save(any())
        verify(repository).flush()
    }

    @Test
    fun `upsert surfaces an update flush failure before returning`() {
        val existing = credential(clientId = WEB_CLIENT_ID)
        val flushFailure = IllegalStateException("database flush failed")
        whenever(repository.findByProviderAndSocialIdAndClientId(SsoType.APPLE, "subject", WEB_CLIENT_ID))
            .thenReturn(existing)
        whenever(cipher.encrypt("new-refresh-token")).thenReturn("new-encrypted-token")
        whenever(repository.flush()).thenThrow(flushFailure)

        val thrown = assertThrows<IllegalStateException> {
            service.upsert("subject", "new-refresh-token", WEB_CLIENT_ID)
        }

        assertThat(thrown).isSameAs(flushFailure)
    }

    @Test
    fun `web upsert does not overwrite an existing legacy native credential`() {
        val legacy = credential(clientId = null, encryptedRefreshToken = "legacy-native-encrypted")
        whenever(repository.findByProviderAndSocialIdAndClientId(SsoType.APPLE, "subject", WEB_CLIENT_ID))
            .thenReturn(null)
        whenever(repository.findByProviderAndSocialIdAndClientIdIsNull(SsoType.APPLE, "subject"))
            .thenReturn(legacy)
        whenever(cipher.encrypt("web-refresh")).thenReturn("web-encrypted")
        whenever(repository.saveAndFlush(any())).thenAnswer { it.arguments[0] }

        service.upsert("subject", "web-refresh", WEB_CLIENT_ID)

        val saved = argumentCaptor<AppleOAuthCredential>()
        verify(repository).saveAndFlush(saved.capture())
        assertThat(saved.firstValue.clientId).isEqualTo(WEB_CLIENT_ID)
        assertThat(legacy.clientId).isNull()
        assertThat(legacy.encryptedRefreshToken).isEqualTo("legacy-native-encrypted")
        verify(repository, never()).findByProviderAndSocialIdAndClientIdIsNull(any(), any())
    }

    @Test
    fun `revocation retry stores an encrypted synthetic orphan without touching an existing subject grant`() {
        whenever(cipher.encrypt("failed-revoke-token")).thenReturn("encrypted-retry-payload")
        whenever(repository.saveAndFlush(any())).thenAnswer { it.arguments[0] }

        service.storeRevocationRetry("failed-revoke-token", WEB_CLIENT_ID)

        val saved = argumentCaptor<AppleOAuthCredential>()
        verify(repository).saveAndFlush(saved.capture())
        assertThat(saved.firstValue.socialId).startsWith("__revoke_pending__:")
        assertThat(saved.firstValue.socialId).doesNotContain("subject")
        assertThat(saved.firstValue.clientId).isEqualTo(WEB_CLIENT_ID)
        assertThat(saved.firstValue.encryptedRefreshToken).isEqualTo("encrypted-retry-payload")
        assertThat(saved.firstValue.encryptedRefreshToken).doesNotContain("failed-revoke-token")
        verify(repository, never()).findByProviderAndSocialIdAndClientId(any(), any(), any())
    }

    @Test
    fun `revocation retry is committed in an independent transaction`() {
        val annotation = AppleCredentialService::class.java
            .getMethod("storeRevocationRetry", String::class.java, String::class.java)
            .getAnnotation(Transactional::class.java)

        assertThat(annotation.propagation).isEqualTo(Propagation.REQUIRES_NEW)
    }

    @Test
    fun `revoke removes every client grant only after all provider revocations succeed`() {
        val native = credential(clientId = NATIVE_CLIENT_ID, encryptedRefreshToken = "native-encrypted")
        val web = credential(clientId = WEB_CLIENT_ID, encryptedRefreshToken = "web-encrypted")
        whenever(repository.findAllByProviderAndSocialId(SsoType.APPLE, "subject"))
            .thenReturn(listOf(native, web))
        whenever(cipher.decrypt("native-encrypted")).thenReturn("native-refresh")
        whenever(cipher.decrypt("web-encrypted")).thenReturn("web-refresh")
        whenever(secrets.create(NATIVE_CLIENT_ID)).thenReturn("native-secret")
        whenever(secrets.create(WEB_CLIENT_ID)).thenReturn("web-secret")

        service.revokeAndDelete("subject")

        val order = inOrder(provider, repository)
        order.verify(provider).revoke("native-refresh", NATIVE_CLIENT_ID, "native-secret")
        order.verify(provider).revoke("web-refresh", WEB_CLIENT_ID, "web-secret")
        order.verify(repository).deleteAll(listOf(native, web))
    }

    @Test
    fun `revoke failure keeps every local client grant for retry`() {
        val native = credential(clientId = NATIVE_CLIENT_ID, encryptedRefreshToken = "native-encrypted")
        val web = credential(clientId = WEB_CLIENT_ID, encryptedRefreshToken = "web-encrypted")
        whenever(repository.findAllByProviderAndSocialId(SsoType.APPLE, "subject"))
            .thenReturn(listOf(native, web))
        whenever(cipher.decrypt("native-encrypted")).thenReturn("native-refresh")
        whenever(cipher.decrypt("web-encrypted")).thenReturn("web-refresh")
        whenever(secrets.create(NATIVE_CLIENT_ID)).thenReturn("native-secret")
        whenever(secrets.create(WEB_CLIENT_ID)).thenReturn("web-secret")
        whenever(provider.revoke("web-refresh", WEB_CLIENT_ID, "web-secret"))
            .thenThrow(AppleOAuthException("auth.apple.provider.unavailable", 503))

        assertThrows<AppleOAuthException> { service.revokeAndDelete("subject") }

        verify(provider).revoke("native-refresh", NATIVE_CLIENT_ID, "native-secret")
        verify(provider).revoke("web-refresh", WEB_CLIENT_ID, "web-secret")
        verify(repository, never()).deleteAll(any<List<AppleOAuthCredential>>())
    }

    @Test
    fun `legacy credential without client id falls back to native client id during revoke`() {
        val legacy = credential(clientId = null)
        whenever(repository.findAllByProviderAndSocialId(SsoType.APPLE, "subject")).thenReturn(listOf(legacy))
        whenever(cipher.decrypt(legacy.encryptedRefreshToken)).thenReturn("refresh-token")
        whenever(secrets.clientId()).thenReturn(NATIVE_CLIENT_ID)
        whenever(secrets.create(NATIVE_CLIENT_ID)).thenReturn("client-secret")

        service.revokeAndDelete("subject")

        verify(provider).revoke("refresh-token", NATIVE_CLIENT_ID, "client-secret")
        verify(repository).deleteAll(listOf(legacy))
    }

    private fun credential(
        clientId: String? = null,
        encryptedRefreshToken: String = "encrypted",
    ) = AppleOAuthCredential(
        socialId = "subject",
        encryptedRefreshToken = encryptedRefreshToken,
        clientId = clientId,
        createdAt = java.time.LocalDateTime.now(clock),
        updatedAt = java.time.LocalDateTime.now(clock),
    )

    companion object {
        private const val NATIVE_CLIENT_ID = "io.github.shanepark.dutypark"
        private const val WEB_CLIENT_ID = "io.github.shanepark.dutypark.web"
    }
}
