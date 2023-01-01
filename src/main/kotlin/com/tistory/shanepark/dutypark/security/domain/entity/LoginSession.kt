package com.tistory.shanepark.dutypark.security.domain.entity

import com.fasterxml.jackson.annotation.JsonIgnore
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import jakarta.persistence.*
import java.util.*

@Entity
class LoginSession(

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id")
    @JsonIgnore
    val member: Member

) {
    @Column(nullable = false, name = "access_token")
    val accessToken: String = UUID.randomUUID().toString()

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null

}
