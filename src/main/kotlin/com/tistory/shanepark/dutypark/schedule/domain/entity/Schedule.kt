package com.tistory.shanepark.dutypark.schedule.domain.entity

import com.tistory.shanepark.dutypark.common.domain.entity.EntityBase
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import jakarta.persistence.*
import java.time.LocalDateTime

@Entity
class Schedule(
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    val member: Member,

    @Column(name = "content", nullable = false, length = 50)
    var content: String,

    @Column(name = "start_date_time", nullable = false)
    var startDateTime: LocalDateTime,

    @Column(name = "end_date_time", nullable = false)
    var endDateTime: LocalDateTime,

    @Column(name = "position", nullable = false)
    var position: Int,

    @Column(name = "visibility", nullable = false)
    @Enumerated(EnumType.STRING)
    var visibility: Visibility = Visibility.FRIENDS

) : EntityBase() {

    @OneToMany(mappedBy = "schedule", fetch = FetchType.LAZY, cascade = [CascadeType.ALL], orphanRemoval = true)
    val tags: MutableList<ScheduleTag> = mutableListOf()

    fun addTag(member: Member) {
        tags.find { it.member.id == member.id }
            ?.let { throw IllegalArgumentException("$member is already tagged in schedule $this") }

        val scheduleTag = ScheduleTag(this, member)
        tags.add(scheduleTag)
    }

    fun removeTag(member: Member) {
        val scheduleTag = tags.find { it.member.id == member.id }
        if (scheduleTag == null) {
            throw IllegalArgumentException("$member is not tagged in schedule $this")
        }
        tags.remove(scheduleTag)
    }

}
