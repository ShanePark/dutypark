package com.tistory.shanepark.dutypark.duty.domain.entity

import com.tistory.shanepark.dutypark.team.domain.entity.Team
import com.tistory.shanepark.dutypark.duty.enums.Color
import jakarta.persistence.*

@Entity
@Table(name = "duty_type")
class DutyType(
    var name: String,
    var position: Int,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "team_id")
    val team: Team,
) {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null

    @Enumerated(value = EnumType.STRING)
    var color: Color? = null

    override fun toString(): String {
        return "DutyType(name='$name', id=$id)"
    }
}
