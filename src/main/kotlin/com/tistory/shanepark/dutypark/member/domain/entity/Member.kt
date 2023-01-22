package com.tistory.shanepark.dutypark.member.domain.entity

import com.fasterxml.jackson.annotation.JsonIgnore
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import jakarta.persistence.*

@Entity
class Member(
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "department_id")
    @field:JsonIgnore
    val department: Department,

    @Column(nullable = false)
    val name: String,

    @Column(unique = true, nullable = false)
    val email: String,

    @Column(nullable = false)
    val password: String,

    ) {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null

    @OneToMany(mappedBy = "member", orphanRemoval = true, cascade = [CascadeType.REMOVE], fetch = FetchType.LAZY)
    val refreshTokens = mutableListOf<RefreshToken>()

}
