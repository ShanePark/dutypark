package com.tistory.shanepark.dutypark.duty.domain.entity

import com.tistory.shanepark.dutypark.duty.enums.Color
import com.tistory.shanepark.dutypark.team.domain.entity.Team
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
        protected set

    @Enumerated(value = EnumType.STRING)
    var color: Color? = null

    @OneToMany(mappedBy = "dutyType", cascade = [CascadeType.ALL], orphanRemoval = true)
    var duties: MutableList<Duty> = mutableListOf()

    override fun toString(): String {
        return "DutyType(name='$name', id=$id)"
    }
}
