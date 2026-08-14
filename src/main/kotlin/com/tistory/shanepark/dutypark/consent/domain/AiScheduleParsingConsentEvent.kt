package com.tistory.shanepark.dutypark.consent.domain

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import jakarta.persistence.*
import java.time.LocalDateTime

@Entity
@Table(
    name = "ai_schedule_parsing_consent_event",
    indexes = [
        Index(
            name = "idx_ai_schedule_parsing_consent_event_member_created",
            columnList = "member_id, created_at, id",
        ),
    ],
)
class AiScheduleParsingConsentEvent(
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    val member: Member,

    @Enumerated(EnumType.STRING)
    @Column(name = "event_type", nullable = false, length = 20)
    val eventType: AiScheduleParsingConsentEventType,

    @Column(name = "policy_version", length = 20)
    val policyVersion: String? = null,

    @Column(name = "created_at", nullable = false)
    val createdAt: LocalDateTime = LocalDateTime.now(),

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
