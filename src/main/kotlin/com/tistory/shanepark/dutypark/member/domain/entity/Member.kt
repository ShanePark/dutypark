package com.tistory.shanepark.dutypark.member.domain.entity

import javax.persistence.*

@Entity
class Member(
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "department_id")
    val department: Department,
    @Column(unique = true)
    val name: String,
    val password: String,
) {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
}
