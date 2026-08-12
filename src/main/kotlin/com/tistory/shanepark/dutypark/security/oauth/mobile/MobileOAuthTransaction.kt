package com.tistory.shanepark.dutypark.security.oauth.mobile

import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import jakarta.persistence.*
import java.time.Instant

@Entity
@Table(name = "mobile_oauth_transaction")
class MobileOAuthTransaction(
    @Enumerated(EnumType.STRING)
    @Column(name = "provider", nullable = false, length = 20)
    val provider: SsoType,

    @Enumerated(EnumType.STRING)
    @Column(name = "purpose", nullable = false, length = 20)
    val purpose: MobileOAuthPurpose,

    @Column(name = "callback_uri", nullable = false, length = 500)
    val callbackUri: String,

    @Column(name = "code_challenge", nullable = false, length = 128)
    val codeChallenge: String,

    @Column(name = "state_hash", nullable = false, unique = true, length = 64)
    val stateHash: String,

    @Column(name = "state_expires_at", nullable = false)
    val stateExpiresAt: Instant,

    @Column(name = "link_member_id")
    val linkMemberId: Long? = null,
) {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
        protected set

    @Column(name = "state_consumed_at")
    var stateConsumedAt: Instant? = null
        protected set

    @Column(name = "exchange_code_hash", unique = true, length = 64)
    var exchangeCodeHash: String? = null
        protected set

    @Column(name = "exchange_expires_at")
    var exchangeExpiresAt: Instant? = null
        protected set

    @Column(name = "exchange_consumed_at")
    var exchangeConsumedAt: Instant? = null
        protected set

    @Column(name = "member_id")
    var memberId: Long? = null
        protected set

    @Column(name = "signup_uuid", length = 36)
    var signupUuid: String? = null
        protected set

    fun completeForMember(codeHash: String, expiresAt: Instant, memberId: Long) {
        complete(codeHash, expiresAt)
        this.memberId = memberId
    }

    fun completeForSignup(codeHash: String, expiresAt: Instant, signupUuid: String) {
        complete(codeHash, expiresAt)
        this.signupUuid = signupUuid
    }

    fun claim(now: Instant) {
        check(stateConsumedAt == null)
        stateConsumedAt = now
    }

    fun consumeExchange(now: Instant) {
        check(exchangeConsumedAt == null)
        exchangeConsumedAt = now
    }

    private fun complete(codeHash: String, expiresAt: Instant) {
        check(stateConsumedAt != null)
        check(exchangeCodeHash == null)
        exchangeCodeHash = codeHash
        exchangeExpiresAt = expiresAt
    }
}
