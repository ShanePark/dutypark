package com.tistory.shanepark.dutypark.schedule.domain.entity

import com.tistory.shanepark.dutypark.common.domain.entity.BaseTimeEntity
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import jakarta.persistence.*

@Entity
@Table(name = "schedule_tags")
class ScheduleTag(

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "schedule_id")
    val schedule: Schedule,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id")
    val member: Member,

    ) : BaseTimeEntity() {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
        protected set

}
