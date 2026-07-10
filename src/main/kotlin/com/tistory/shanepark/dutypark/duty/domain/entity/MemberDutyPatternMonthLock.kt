package com.tistory.shanepark.dutypark.duty.domain.entity

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import jakarta.persistence.*
import java.time.LocalDate

@Entity
@Table(
    name = "member_duty_pattern_month_lock",
    uniqueConstraints = [UniqueConstraint(columnNames = ["member_id", "team_id", "month_start"])]
)
class MemberDutyPatternMonthLock(
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "member_id", nullable = false)
    val member: Member,

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "team_id", nullable = false)
    val team: Team,

    @Column(name = "month_start", nullable = false)
    val yearMonth: LocalDate,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "pattern_id")
    val pattern: MemberDutyPattern?,

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(
        name = "member_duty_pattern_month_lock_workday",
        joinColumns = [JoinColumn(name = "lock_id")],
    )
    @Column(name = "duty_date", nullable = false)
    val baselineWorkDates: MutableSet<LocalDate> = mutableSetOf(),
) {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
        protected set
}
