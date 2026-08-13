package com.tistory.shanepark.dutypark.security.oauth.apple

import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.LocalDateTime

@Service
@Transactional
class AppleCredentialService(
    private val repository: AppleOAuthCredentialRepository,
    private val cipher: AppleCredentialCipher,
    private val providerClient: AppleProviderClient,
    private val clientSecretFactory: AppleClientSecretFactory,
    private val clock: Clock,
) {
    fun ensureConfigured() = cipher.ensureConfigured()

    fun upsert(subject: String, refreshToken: String) {
        val now = LocalDateTime.now(clock)
        val encrypted = cipher.encrypt(refreshToken)
        val credential = repository.findByProviderAndSocialId(SsoType.APPLE, subject)
        if (credential == null) {
            repository.save(AppleOAuthCredential(SsoType.APPLE, subject, encrypted, now, now))
        } else {
            credential.encryptedRefreshToken = encrypted
            credential.updatedAt = now
        }
    }

    fun revokeAndDelete(subject: String) {
        val credential = repository.findByProviderAndSocialId(SsoType.APPLE, subject) ?: return
        providerClient.revoke(
            cipher.decrypt(credential.encryptedRefreshToken),
            clientSecretFactory.clientId(),
            clientSecretFactory.create(),
        )
        repository.delete(credential)
    }
}
