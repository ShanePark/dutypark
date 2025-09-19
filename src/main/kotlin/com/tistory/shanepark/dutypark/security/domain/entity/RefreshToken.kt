package com.tistory.shanepark.dutypark.security.domain.entity

import com.fasterxml.jackson.annotation.JsonIgnore
import com.tistory.shanepark.dutypark.common.domain.entity.BaseTimeEntity
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import jakarta.persistence.*
import jakarta.servlet.http.Cookie
import java.time.LocalDateTime
import java.time.ZoneOffset
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
    @Column(name = "user_agent", nullable = true)
    var userAgent: String?,

    ) : BaseTimeEntity() {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
        protected set

    @Column(name = "refresh_token", nullable = false)
    val token: String = UUID.randomUUID().toString()

    @Column(name = "last_used", nullable = false)
    var lastUsed: LocalDateTime = LocalDateTime.now()

    fun validation(remoteAddr: String?, userAgent: String?): Boolean {
        return validUntil.isAfter(LocalDateTime.now())
    }

    fun isValid(): Boolean {
        return this.validUntil.isAfter(LocalDateTime.now())
    }

    fun slideValidUntil(remoteAddr: String?, userAgent: String?, validityDays: Long) {
        validUntil = LocalDateTime.now().plusDays(validityDays)
        this.lastUsed = LocalDateTime.now()
        this.remoteAddr = remoteAddr
        this.userAgent = userAgent
    }

    fun createCookie(): Cookie {
        val maxAge = validUntil.toEpochSecond(ZoneOffset.UTC) - LocalDateTime.now().toEpochSecond(ZoneOffset.UTC)
        return Cookie(cookieName, this.token).apply {
            this.path = "/"
            this.maxAge = maxAge.toInt()
            this.isHttpOnly = true
        }
    }

    companion object {
        const val cookieName: String = "REFRESH_TOKEN"
    }
}
