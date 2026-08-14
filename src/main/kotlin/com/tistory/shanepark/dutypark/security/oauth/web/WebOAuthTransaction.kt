package com.tistory.shanepark.dutypark.security.oauth.web

import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
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
@Table(name = "web_oauth_transaction")
class WebOAuthTransaction(
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    val provider: SsoType,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    val purpose: WebOAuthPurpose,

    @Column(name = "referer", nullable = false, length = 500)
    val referer: String,

    @Column(name = "state_hash", nullable = false, unique = true, length = 64)
    val stateHash: String,

    @Column(name = "browser_session_hash", nullable = false, length = 64)
    val browserSessionHash: String,

    @Column(name = "state_expires_at", nullable = false)
    val stateExpiresAt: Instant,

    @Column(name = "link_member_id")
    val authenticatedMemberId: Long? = null,
) {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
        protected set

    @Column(name = "state_consumed_at")
    var stateConsumedAt: Instant? = null
        protected set

    fun consume(now: Instant) {
        check(stateConsumedAt == null)
        stateConsumedAt = now
    }
}
