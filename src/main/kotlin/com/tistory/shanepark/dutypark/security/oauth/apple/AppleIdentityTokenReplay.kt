package com.tistory.shanepark.dutypark.security.oauth.apple

import jakarta.persistence.*
import java.time.LocalDateTime

@Entity
@Table(
    name = "apple_identity_token_replay",
    uniqueConstraints = [UniqueConstraint(name = "uk_apple_identity_token_replay_hash", columnNames = ["token_hash"])],
)
class AppleIdentityTokenReplay(
    @Column(name = "token_hash", nullable = false, length = 64)
    val tokenHash: String,
    @Column(name = "expires_at", nullable = false)
    val expiresAt: LocalDateTime,
    @Column(name = "created_at", nullable = false)
    val createdAt: LocalDateTime,
) {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
        protected set
}

interface AppleIdentityTokenReplayRepository : org.springframework.data.jpa.repository.JpaRepository<AppleIdentityTokenReplay, Long> {
    fun existsByTokenHash(tokenHash: String): Boolean
    fun deleteByExpiresAtBefore(cutoff: LocalDateTime): Long
}

@org.springframework.stereotype.Service
class AppleIdentityTokenReplayService(
    private val repository: AppleIdentityTokenReplayRepository,
    private val clock: java.time.Clock,
) {
    @org.springframework.transaction.annotation.Transactional(
        propagation = org.springframework.transaction.annotation.Propagation.REQUIRES_NEW
    )
    fun consume(tokenHash: String, expiresAtEpochSecond: Long) {
        if (repository.existsByTokenHash(tokenHash)) {
            throw AppleOAuthException("auth.apple.credential.invalid")
        }
        try {
            repository.saveAndFlush(
                AppleIdentityTokenReplay(
                    tokenHash,
                    java.time.LocalDateTime.ofInstant(
                        java.time.Instant.ofEpochSecond(expiresAtEpochSecond),
                        java.time.ZoneOffset.UTC,
                    ),
                    java.time.LocalDateTime.ofInstant(clock.instant(), java.time.ZoneOffset.UTC),
                )
            )
        } catch (_: org.springframework.dao.DataIntegrityViolationException) {
            throw AppleOAuthException("auth.apple.credential.invalid")
        }
    }
}
