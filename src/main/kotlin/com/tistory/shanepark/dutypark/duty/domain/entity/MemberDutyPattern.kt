package com.tistory.shanepark.dutypark.duty.domain.entity

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import jakarta.persistence.*
import java.time.DayOfWeek
import java.time.LocalDate

@Entity
@Table(name = "member_duty_pattern")
class MemberDutyPattern(
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "member_id", nullable = false)
    val member: Member,

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "team_id", nullable = false)
    val team: Team,

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "duty_type_id", nullable = false)
    val dutyType: DutyType,

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(
        name = "member_duty_pattern_weekday",
        joinColumns = [JoinColumn(name = "pattern_id")]
    )
    @Column(name = "weekday", nullable = false, length = 16)
    @Enumerated(EnumType.STRING)
    val weekdays: MutableSet<DayOfWeek> = mutableSetOf(),

    @Column(name = "holiday_off", nullable = false)
    val holidayOff: Boolean,

    @Column(name = "effective_from", nullable = false)
    val effectiveFrom: LocalDate,
) {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
        protected set

    @Column(name = "effective_until_exclusive")
    var effectiveUntilExclusive: LocalDate? = null
        protected set

    fun closeAt(date: LocalDate) {
        effectiveUntilExclusive = date
    }

    fun appliesOn(date: LocalDate): Boolean =
        !date.isBefore(effectiveFrom) && (effectiveUntilExclusive == null || date.isBefore(effectiveUntilExclusive))
}
