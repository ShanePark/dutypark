package com.tistory.shanepark.dutypark.security.reauth

import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.EnumType
import jakarta.persistence.Enumerated
import jakarta.persistence.GeneratedValue
import jakarta.persistence.GenerationType
import jakarta.persistence.Id
import jakarta.persistence.Table
import java.time.Instant

@Entity
@Table(name = "account_reauth_proof")
class ReauthProof(
    @Enumerated(EnumType.STRING)
    @Column(name = "purpose", nullable = false, length = 30)
    val purpose: ReauthPurpose,

    @Column(name = "proof_hash", nullable = false, unique = true, length = 64)
    val proofHash: String,

    @Column(name = "member_id", nullable = false)
    val memberId: Long,

    @Column(name = "expires_at", nullable = false)
    val expiresAt: Instant,

    @Column(name = "created_at", nullable = false, updatable = false)
    val createdAt: Instant,
) {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
        protected set

    @Column(name = "consumed_at")
    var consumedAt: Instant? = null
        protected set

    fun consume(now: Instant) {
        check(consumedAt == null)
        consumedAt = now
    }
}
