package com.tistory.shanepark.dutypark.member.domain.entity

import com.tistory.shanepark.dutypark.policy.domain.enums.PolicyType
import jakarta.persistence.*
import java.time.LocalDateTime

@Entity
@Table(
    name = "member_consent",
    indexes = [Index(name = "idx_member_consent_member_type", columnList = "member_id, policy_type")]
)
class MemberConsent(
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    val member: Member,

    @Enumerated(EnumType.STRING)
    @Column(name = "policy_type", nullable = false, length = 50)
    val policyType: PolicyType,

    @Column(name = "consent_version", nullable = false, length = 20)
    val consentVersion: String,

    @Column(name = "consented_at", nullable = false)
    val consentedAt: LocalDateTime = LocalDateTime.now(),

    @Column(name = "ip_address", length = 45)
    val ipAddress: String? = null,

    @Column(name = "user_agent", length = 500)
    val userAgent: String? = null,
) {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
        protected set
}
