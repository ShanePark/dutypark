package com.tistory.shanepark.dutypark.member.domain

import javax.persistence.*

@Entity
class Department(
    @Column(unique = true)
    val name: String
) {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
}
