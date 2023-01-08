package com.tistory.shanepark.dutypark.member.domain.entity

import jakarta.persistence.*

@Entity
class Member(
    @ManyToOne(fetch = FetchType.LAZY, cascade = [CascadeType.ALL])
    @JoinColumn(name = "department_id")
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

}
