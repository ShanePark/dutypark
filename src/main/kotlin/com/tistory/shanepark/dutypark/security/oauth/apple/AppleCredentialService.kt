package com.tistory.shanepark.dutypark.security.oauth.apple

import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Propagation
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.LocalDateTime
import java.util.UUID

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

    fun upsert(subject: String, refreshToken: String, clientId: String) {
        val now = LocalDateTime.now(clock)
        val encrypted = cipher.encrypt(refreshToken)
        val credential = repository.findByProviderAndSocialIdAndClientId(SsoType.APPLE, subject, clientId)
            ?: if (clientSecretFactory.isNativeClientId(clientId)) {
                repository.findByProviderAndSocialIdAndClientIdIsNull(SsoType.APPLE, subject)
            } else {
                null
            }
        if (credential == null) {
            repository.saveAndFlush(
                AppleOAuthCredential(
                    provider = SsoType.APPLE,
                    socialId = subject,
                    clientId = clientId,
                    encryptedRefreshToken = encrypted,
                    createdAt = now,
                    updatedAt = now,
                )
            )
        } else {
            credential.clientId = clientId
            credential.encryptedRefreshToken = encrypted
            credential.updatedAt = now
            repository.flush()
        }
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun storeRevocationRetry(refreshToken: String, clientId: String) {
        val now = LocalDateTime.now(clock)
        repository.saveAndFlush(
            AppleOAuthCredential(
                socialId = "$REVOCATION_RETRY_PREFIX${UUID.randomUUID()}",
                clientId = clientId,
                encryptedRefreshToken = cipher.encrypt(refreshToken),
                createdAt = now,
                updatedAt = now,
            )
        )
    }

    fun revokeAndDelete(subject: String) {
        val credentials = repository.findAllByProviderAndSocialId(SsoType.APPLE, subject)
        credentials.forEach { credential ->
            val clientId = credential.clientId ?: clientSecretFactory.clientId()
            providerClient.revoke(
                cipher.decrypt(credential.encryptedRefreshToken),
                clientId,
                clientSecretFactory.create(clientId),
            )
        }
        repository.deleteAll(credentials)
    }

    companion object {
        private const val REVOCATION_RETRY_PREFIX = "__revoke_pending__:"
    }
}
