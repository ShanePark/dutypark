package com.tistory.shanepark.dutypark.member.domain.entity

import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.EnumType
import jakarta.persistence.Enumerated
import jakarta.persistence.FetchType
import jakarta.persistence.GeneratedValue
import jakarta.persistence.GenerationType
import jakarta.persistence.Id
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import jakarta.persistence.UniqueConstraint
import java.time.LocalDateTime

@Entity
@Table(
    name = "member_social_account",
    uniqueConstraints = [
        UniqueConstraint(
            name = "uk_member_social_account_provider_social_id",
            columnNames = ["provider", "social_id"]
        ),
        UniqueConstraint(
            name = "uk_member_social_account_member_provider",
            columnNames = ["member_id", "provider"]
        )
    ]
)
class MemberSocialAccount(
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    val member: Member,

    @Enumerated(EnumType.STRING)
    @Column(name = "provider", nullable = false)
    val provider: SsoType,

    @Column(name = "social_id", nullable = false)
    val socialId: String,
) {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
        protected set

    @Column(name = "created_date", nullable = false)
    val createdDate: LocalDateTime = LocalDateTime.now()
}
