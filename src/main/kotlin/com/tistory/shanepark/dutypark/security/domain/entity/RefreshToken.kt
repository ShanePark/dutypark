package com.tistory.shanepark.dutypark.security.domain.entity

import com.fasterxml.jackson.annotation.JsonIgnore
import com.tistory.shanepark.dutypark.common.domain.entity.BaseTimeEntity
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.security.domain.dto.UserAgentInfo
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
    var validUntil: LocalDateTime,

    @Column(name = "remote_addr", nullable = true)
    var remoteAddr: String?,

    userAgent: String?,

    ) : BaseTimeEntity() {

    @Column(name = "user_agent", nullable = true)
    var userAgent: String? = UserAgentInfo.parse(userAgent)?.toJson()

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
        protected set

    @Column(name = "refresh_token", nullable = false)
    val token: String = UUID.randomUUID().toString()

    @Column(name = "last_used", nullable = false)
    var lastUsed: LocalDateTime = LocalDateTime.now()

    fun isValid(): Boolean {
        return this.validUntil.isAfter(LocalDateTime.now())
    }

    fun slideValidUntil(remoteAddr: String?, userAgent: String?, validityDays: Long) {
        validUntil = LocalDateTime.now().plusDays(validityDays)
        this.lastUsed = LocalDateTime.now()
        this.remoteAddr = remoteAddr
        this.userAgent = UserAgentInfo.parse(userAgent)?.toJson()
    }

}
