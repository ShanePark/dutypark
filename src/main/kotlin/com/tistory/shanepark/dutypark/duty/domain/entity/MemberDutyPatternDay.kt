package com.tistory.shanepark.dutypark.duty.domain.entity

import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.EnumType
import jakarta.persistence.Enumerated
import jakarta.persistence.FetchType
import jakarta.persistence.Id
import jakarta.persistence.IdClass
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import java.io.Serializable
import java.time.DayOfWeek

data class MemberDutyPatternDayId(
    var pattern: Long? = null,
    var weekday: DayOfWeek? = null,
) : Serializable

@Entity
@Table(name = "member_duty_pattern_weekday")
@IdClass(MemberDutyPatternDayId::class)
class MemberDutyPatternDay(
    @Id
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "pattern_id", nullable = false)
    val pattern: MemberDutyPattern,

    @Id
    @Enumerated(EnumType.STRING)
    @Column(name = "weekday", nullable = false, length = 16)
    val weekday: DayOfWeek,

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "duty_type_id", nullable = false)
    val dutyType: DutyType,
)
