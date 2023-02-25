package com.tistory.shanepark.dutypark.member.domain.entity

import com.tistory.shanepark.dutypark.common.entity.BaseTimeEntity
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.enums.Color
import jakarta.persistence.*

@Entity
class Department(
    @Column(unique = true)
    val name: String,

    @Enumerated(EnumType.STRING)
    var offColor: Color = Color.GREY,
) : BaseTimeEntity() {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null

    @OneToMany(mappedBy = "department")
    val dutyTypes: MutableList<DutyType> = mutableListOf()
}
