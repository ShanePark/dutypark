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
    @JoinColumn(name = "member_id", nullable = false)
    val member: Member = member

    @Column(name = "start_date_time", nullable = false)
    var startDateTime: LocalDateTime = startDateTime

    @Column(name = "end_date_time", nullable = false)
    var endDateTime: LocalDateTime = endDateTime

    @Column(name = "content", nullable = false, length = 50)
    var content: String = content

    @Column(name = "position", nullable = false)
    var position: Int = position

}
