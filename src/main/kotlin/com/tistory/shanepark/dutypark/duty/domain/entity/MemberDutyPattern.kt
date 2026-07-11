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

    dayTypes: Map<DayOfWeek, DutyType>,

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

    @OneToMany(mappedBy = "pattern", cascade = [CascadeType.ALL], orphanRemoval = true, fetch = FetchType.EAGER)
    val days: MutableList<MemberDutyPatternDay> = dayTypes
        .map { (weekday, dutyType) -> MemberDutyPatternDay(this, weekday, dutyType) }
        .toMutableList()

    fun closeAt(date: LocalDate) {
        effectiveUntilExclusive = date
    }

    fun appliesOn(date: LocalDate): Boolean =
        !date.isBefore(effectiveFrom) && (effectiveUntilExclusive == null || date.isBefore(effectiveUntilExclusive))

    fun dutyTypeOn(weekday: DayOfWeek): DutyType? =
        days.firstOrNull { it.weekday == weekday }?.dutyType

    fun dayTypeIds(): Map<DayOfWeek, Long?> =
        days.associate { it.weekday to it.dutyType.id }
}
