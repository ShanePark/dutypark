package com.tistory.shanepark.dutypark.duty.domain.entity

import com.tistory.shanepark.dutypark.team.domain.entity.Team
import jakarta.persistence.*

@Entity
@Table(name = "duty_type")
class DutyType(
    @Column(length = 10)
    var name: String,
    var position: Int,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "team_id")
    val team: Team,

    @Column(length = 7)
    var color: String
) {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
        protected set

    @OneToMany(mappedBy = "dutyType", cascade = [CascadeType.ALL], orphanRemoval = true)
    var duties: MutableList<Duty> = mutableListOf()

    override fun toString(): String {
        return "DutyType(name='$name', id=$id)"
    }
}
