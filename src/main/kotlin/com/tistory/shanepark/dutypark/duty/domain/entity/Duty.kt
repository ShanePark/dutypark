package com.tistory.shanepark.dutypark.duty.domain.entity

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import jakarta.persistence.*
import java.time.LocalDate

@Entity
class Duty(
    @Column(name = "duty_date")
    val dutyDate: LocalDate,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "duty_type_id")
    var dutyType: DutyType?,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id")
    val member: Member,
) {

    constructor(
        dutyYear: Int,
        dutyMonth: Int,
        dutyDay: Int,
        dutyType: DutyType,
        member: Member
    ) : this(LocalDate.of(dutyYear, dutyMonth, dutyDay), dutyType, member)

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null

}
