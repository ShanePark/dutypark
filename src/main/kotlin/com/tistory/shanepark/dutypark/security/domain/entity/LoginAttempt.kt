package com.tistory.shanepark.dutypark.security.domain.entity

import com.tistory.shanepark.dutypark.common.domain.entity.BaseTimeEntity
import jakarta.persistence.*
import java.time.LocalDateTime

@Entity
@Table(name = "login_attempt")
class LoginAttempt(

    @Column(name = "ip_address", nullable = false, length = 45)
    val ipAddress: String,

    @Column(name = "email", nullable = false)
    val email: String,

    @Column(name = "attempt_time", nullable = false)
    val attemptTime: LocalDateTime,

    @Column(name = "success", nullable = false)
    val success: Boolean = false

) : BaseTimeEntity() {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
        protected set

}
