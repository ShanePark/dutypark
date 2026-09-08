package com.tistory.shanepark.dutypark.duty.domain.entity

import com.tistory.shanepark.dutypark.duty.domain.DutyAbbreviation
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
    var color: String,

    @Column(nullable = false)
    var hidden: Boolean = false,

    @Column(length = 10)
    var abbreviation: String? = null,
) {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
        protected set

    @OneToMany(mappedBy = "dutyType", cascade = [CascadeType.ALL], orphanRemoval = true)
    var duties: MutableList<Duty> = mutableListOf()

    @get:Transient
    val shortName: String
        get() = DutyAbbreviation.resolve(name, abbreviation)

    override fun toString(): String {
        return "DutyType(name='$name', id=$id)"
    }
}
