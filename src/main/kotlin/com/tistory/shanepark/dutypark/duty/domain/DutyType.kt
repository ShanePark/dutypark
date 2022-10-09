package com.tistory.shanepark.dutypark.duty.domain

import com.tistory.shanepark.dutypark.member.domain.Department
import javax.persistence.*

@Entity
@Table(name = "duty_type")
class DutyType(
    val name: String,
    val index: Int,
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "department_id")
    val department: Department,
) {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
}
