package com.tistory.shanepark.dutypark.department.domain.entity

import com.tistory.shanepark.dutypark.common.domain.entity.BaseTimeEntity
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTemplate
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.enums.Color
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import jakarta.persistence.*

@Entity
class Department(
    @Column(unique = true)
    var name: String,
) : BaseTimeEntity() {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null
        protected set

    var description: String = ""

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "manager_id")
    var manager: Member? = null

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, name = "default_duty_color")
    var defaultDutyColor: Color = Color.GREY

    @Column(nullable = false, name = "default_duty_name")
    var defaultDutyName: String = "OFF"

    @OneToMany(mappedBy = "department", fetch = FetchType.LAZY, cascade = [CascadeType.ALL], orphanRemoval = true)
    val dutyTypes: MutableList<DutyType> = mutableListOf()

    @OneToMany(mappedBy = "department", fetch = FetchType.LAZY)
    val members: MutableList<Member> = mutableListOf()

    @Enumerated(EnumType.STRING)
    @Column(name = "duty_batch_template")
    var dutyBatchTemplate: DutyBatchTemplate? = null

    fun addMember(member: Member) {
        members.add(member)
        member.department = this
    }

    fun removeMember(member: Member) {
        members.remove(member)
        member.department = null
    }

    fun addDutyType(dutyName: String, dutyColor: Color? = null): DutyType {
        if (dutyTypes.any { it.name == dutyName }) {
            throw IllegalArgumentException("DutyType already exists")
        }

        val maxPosition = dutyTypes.maxOfOrNull { it.position } ?: -1

        val dutyType = DutyType(dutyName, maxPosition + 1, this)
        dutyColor?.let { dutyType.color = it }
        dutyTypes.add(dutyType)
        return dutyType
    }

    fun changeManager(member: Member?) {
        this.manager = member
    }

}
