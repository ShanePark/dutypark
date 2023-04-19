package com.tistory.shanepark.dutypark.schedule.domain.entity

import com.tistory.shanepark.dutypark.common.domain.entity.EntityBase
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import jakarta.persistence.*
import java.time.LocalDateTime

@Entity
class Schedule(
    member: Member,
    content: String,
    startDateTime: LocalDateTime,
    endDateTime: LocalDateTime,
    position: Int,
) : EntityBase() {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id")
    val member: Member = member

    @Column(name = "start_date_time")
    var startDateTime: LocalDateTime = startDateTime

    @Column(name = "end_date_time")
    var endDateTime: LocalDateTime = endDateTime

    var content: String = content

    var position: Int = position

}
