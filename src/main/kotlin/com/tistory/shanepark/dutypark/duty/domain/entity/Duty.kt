package com.tistory.shanepark.dutypark.duty.domain.entity

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import jakarta.persistence.*

@Entity
class Duty(
    val dutyYear: Int,
    val dutyMonth: Int,
    val dutyDay: Int,
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "duty_type_id")
    var dutyType: DutyType?,
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id")
    val member: Member,
) {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null

}
