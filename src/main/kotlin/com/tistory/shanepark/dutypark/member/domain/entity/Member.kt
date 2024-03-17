package com.tistory.shanepark.dutypark.member.domain.entity

import com.fasterxml.jackson.annotation.JsonIgnore
import com.tistory.shanepark.dutypark.department.domain.entity.Department
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import jakarta.persistence.*

@Entity
class Member(
    @Column
    var name: String,

    @Column(unique = true)
    val email: String,

    @Column(nullable = false)
    var password: String,

    ) {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "department_id")
    @field:JsonIgnore
    var department: Department? = null

    @Column(nullable = false, name = "calendar_visibility")
    @Enumerated(EnumType.STRING)
    var calendarVisibility: Visibility = Visibility.FRIENDS

    @Column(name = "oauth_kakao_id")
    var kakaoId: String? = null

    override fun toString(): String {
        return "Member(name='$name', email='$email', id=$id)"
    }


}
