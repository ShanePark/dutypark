package com.tistory.shanepark.dutypark.duty.domain

import com.tistory.shanepark.dutypark.member.domain.Member
import javax.persistence.*

@Entity
class Duty(
    val dutyYear: Int,
    val dutyMonth: Int,
    val dutyDay: Int,
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "duty_type_id")
    val dutyType: DutyType,
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id")
    val member: Member,
    val memo: String? = null
) {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null

}
