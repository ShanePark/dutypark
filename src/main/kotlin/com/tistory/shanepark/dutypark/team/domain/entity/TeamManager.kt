package com.tistory.shanepark.dutypark.team.domain.entity

import com.tistory.shanepark.dutypark.common.domain.entity.EntityBase
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import jakarta.persistence.*

@Entity
@Table(name = "team_managers")
class TeamManager(

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "team_id")
    val team: Team,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id")
    val member: Member

) : EntityBase(

)
