package com.tistory.shanepark.dutypark.team.domain.entity

import com.tistory.shanepark.dutypark.common.domain.entity.EntityBase
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.team.domain.dto.TeamScheduleSaveDto
import jakarta.persistence.*
import jakarta.persistence.FetchType.LAZY
import java.time.LocalDateTime

@Entity
@Table(name = "team_schedule")
class TeamSchedule(

    @ManyToOne(fetch = LAZY)
    @JoinColumn(name = "team_id", nullable = false)
    val team: Team,

    @ManyToOne(fetch = LAZY)
    @JoinColumn(name = "create_member_id", nullable = false)
    val createMember: Member,

    @ManyToOne(fetch = LAZY)
    @JoinColumn(name = "update_member_id", nullable = false)
    var updateMember: Member = createMember,

    @Column(name = "content", nullable = false, length = 50)
    var content: String,

    @Column(name = "description", nullable = false, length = 4096)
    var description: String = "",

    @Column(name = "start_date_time", nullable = false)
    var startDateTime: LocalDateTime,

    @Column(name = "end_date_time", nullable = false)
    var endDateTime: LocalDateTime,

    @Column(name = "position", nullable = false)
    var position: Int = -1,

    ) : EntityBase() {

    fun update(saveDto: TeamScheduleSaveDto, updateMember: Member) {
        this.content = saveDto.content
        this.description = saveDto.description
        this.startDateTime = saveDto.startDateTime
        this.endDateTime = saveDto.endDateTime
        this.updateMember = updateMember
    }

}
