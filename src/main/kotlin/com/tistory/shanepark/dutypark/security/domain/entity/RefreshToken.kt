package com.tistory.shanepark.dutypark.security.domain.entity

import com.fasterxml.jackson.annotation.JsonIgnore
import com.tistory.shanepark.dutypark.common.entity.BaseTimeEntity
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import jakarta.persistence.*
import java.time.LocalDateTime
import java.util.*

@Entity
class RefreshToken(
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id")
    @JsonIgnore
    val member: Member,

    @Column(name = "valid_until")
    var validUntil: LocalDateTime

) : BaseTimeEntity() {
    fun slideValidUntil() {
        if (validUntil.isBefore(LocalDateTime.now().plusWeeks(1))) {
            validUntil = LocalDateTime.now().plusMonths(1)
        }
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null

    @Column(name = "refresh_token")
    val token: String = UUID.randomUUID().toString()

}
