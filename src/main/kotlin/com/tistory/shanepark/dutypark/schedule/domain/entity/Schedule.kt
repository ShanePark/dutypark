package com.tistory.shanepark.dutypark.schedule.domain.entity

import com.tistory.shanepark.dutypark.common.domain.entity.EntityBase
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.schedule.domain.enums.ParsingTimeStatus
import jakarta.persistence.*
import org.hibernate.annotations.DynamicUpdate
import org.hibernate.annotations.JdbcTypeCode
import org.hibernate.type.SqlTypes
import java.time.LocalDateTime
import java.util.UUID

@Entity
@DynamicUpdate
class Schedule(
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id", nullable = false)
    val member: Member,

    @Column(name = "content", nullable = false, length = 50)
    var content: String,

    @Lob
    @Column(name = "description", nullable = false, columnDefinition = "TEXT")
    var description: String = "",

    @Column(name = "start_date_time", nullable = false)
    var startDateTime: LocalDateTime,

    @Column(name = "end_date_time", nullable = false)
    var endDateTime: LocalDateTime,

    @Column(name = "position", nullable = false)
    var position: Int = -1,

    @Column(name = "visibility", nullable = false)
    @Enumerated(EnumType.STRING)
    var visibility: Visibility = Visibility.FRIENDS,

    @Column(name = "parsing_time_status")
    @Enumerated(EnumType.STRING)
    var parsingTimeStatus: ParsingTimeStatus = ParsingTimeStatus.WAIT,

    ) : EntityBase() {

    @Column(name = "content_without_time")
    var contentWithoutTime: String = ""

    @Column(name = "parsing_generation", nullable = false, columnDefinition = "char(36)")
    @JdbcTypeCode(SqlTypes.VARCHAR)
    var parsingGeneration: UUID = UUID.randomUUID()
        protected set

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

    fun hasTimeInfo(): Boolean {
        return startDateTime.hour != 0 || startDateTime.minute != 0
    }

    fun content(): String {
        return contentWithoutTime.ifBlank { content }
    }

    fun updateParsingInput(
        content: String,
        startDateTime: LocalDateTime,
        endDateTime: LocalDateTime,
    ): Boolean {
        val contentChanged = content != content()
        val timeChanged = this.startDateTime != startDateTime || this.endDateTime != endDateTime
        val changed = contentChanged || timeChanged

        if (!changed) return false

        this.content = content
        this.startDateTime = startDateTime
        this.endDateTime = endDateTime
        contentWithoutTime = ""
        parsingTimeStatus = ParsingTimeStatus.WAIT
        parsingGeneration = UUID.randomUUID()
        return true
    }

}
