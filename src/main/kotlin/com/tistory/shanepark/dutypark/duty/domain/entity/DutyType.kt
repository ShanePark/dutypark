package com.tistory.shanepark.dutypark.duty.domain.entity

import com.tistory.shanepark.dutypark.department.domain.entity.Department
import com.tistory.shanepark.dutypark.duty.enums.Color
import jakarta.persistence.*

@Entity
@Table(name = "duty_type")
class DutyType(
    val name: String,
    val position: Int,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "department_id")
    val department: Department,

    @Enumerated(value = EnumType.STRING)
    val color: Color,
) {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
}
