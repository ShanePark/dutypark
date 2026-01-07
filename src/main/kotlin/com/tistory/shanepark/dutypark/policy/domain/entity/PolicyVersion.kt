package com.tistory.shanepark.dutypark.policy.domain.entity

import com.tistory.shanepark.dutypark.policy.domain.enums.PolicyType
import jakarta.persistence.*
import java.time.LocalDate
import java.time.LocalDateTime

@Entity
@Table(
    name = "policy_version",
    uniqueConstraints = [UniqueConstraint(columnNames = ["policy_type", "version"])]
)
class PolicyVersion(
    @Enumerated(EnumType.STRING)
    @Column(name = "policy_type", nullable = false, length = 50)
    val policyType: PolicyType,

    @Column(name = "version", nullable = false, length = 20)
    val version: String,

    @Column(name = "content", columnDefinition = "TEXT", nullable = false)
    val content: String,

    @Column(name = "effective_date", nullable = false)
    val effectiveDate: LocalDate,

    @Column(name = "created_at", nullable = false)
    val createdAt: LocalDateTime = LocalDateTime.now()
) {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
        protected set
}
