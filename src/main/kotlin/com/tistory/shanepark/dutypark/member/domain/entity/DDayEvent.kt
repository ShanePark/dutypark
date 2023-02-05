package com.tistory.shanepark.dutypark.member.domain.entity

import jakarta.persistence.*
import java.time.LocalDate

@Entity
@Table(name = "d_day_event")
class DDayEvent(
    @ManyToOne
    @JoinColumn(name = "member_id")
    val member: Member,

    var title: String,
    var date: LocalDate,
    var isPrivate: Boolean = false,
    var position: Long,
) {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null

}
