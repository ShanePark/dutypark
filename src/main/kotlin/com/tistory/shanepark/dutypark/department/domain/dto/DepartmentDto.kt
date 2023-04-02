package com.tistory.shanepark.dutypark.department.domain.dto

import com.tistory.shanepark.dutypark.common.domain.dto.BaseTimeDto
import com.tistory.shanepark.dutypark.department.domain.entity.Department
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeDto
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto

data class DepartmentDto(
    val id: Long,
    val name: String,
    val dutyTypes: List<DutyTypeDto>,
    val members: List<MemberDto>,
    val baseTime: BaseTimeDto
) {
    companion object {
        fun of(department: Department): DepartmentDto {
            val dutyTypes = department.dutyTypes
                .map { DutyTypeDto(it.id, it.name, it.position, it.color.toString()) }
            val members = department.members
                .map { MemberDto(it) }

            return DepartmentDto(
                id = department.id!!,
                name = department.name,
                dutyTypes = dutyTypes,
                members = members,
                baseTime = department.baseTimeDto()
            )
        }
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is DepartmentDto) return false

        if (id != other.id) return false

        return true
    }

    override fun hashCode(): Int {
        return id.hashCode()
    }

}
