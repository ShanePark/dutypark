package com.tistory.shanepark.dutypark.department.domain.entity

import com.tistory.shanepark.dutypark.common.domain.entity.BaseTimeEntity
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.enums.Color
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import jakarta.persistence.*

@Entity
class Department(
    @Column(unique = true)
    var name: String,
) : BaseTimeEntity() {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null

    var description: String = ""

    @Enumerated(EnumType.STRING)
    var offColor: Color = Color.GREY

    @OneToMany(mappedBy = "department")
    val dutyTypes: MutableList<DutyType> = mutableListOf()

    @OneToMany(mappedBy = "department")
    val members: MutableList<Member> = mutableListOf()

    fun addMember(member: Member) {
        members.add(member)
        member.department = this
    }

}
