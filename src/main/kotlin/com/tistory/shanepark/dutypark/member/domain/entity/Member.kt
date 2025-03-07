package com.tistory.shanepark.dutypark.member.domain.entity

import com.tistory.shanepark.dutypark.department.domain.entity.Department
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import jakarta.persistence.*

@Entity
class Member(
    @Column(nullable = false)
    var name: String,

    @Column
    val email: String? = null,

    @Column
    var password: String? = null,

    ) {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null


    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "department_id")
    var department: Department? = null

    @Column(nullable = false, name = "calendar_visibility")
    @Enumerated(EnumType.STRING)
    var calendarVisibility: Visibility = Visibility.FRIENDS

    @Column(name = "oauth_kakao_id")
    var kakaoId: String? = null

    override fun toString(): String {
        return "Member(name='$name', email='$email', id=$id)"
    }

    fun isDepartmentManager(isManager: LoginMember): Boolean {
        return this.department?.manager?.id == isManager.id
    }

    fun isEquals(loginMember: LoginMember): Boolean {
        return this.id == loginMember.id
    }

}
