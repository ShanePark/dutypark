package com.tistory.shanepark.dutypark.department.domain.dto

import com.tistory.shanepark.dutypark.department.domain.entity.Department
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeDto
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.member.domain.entity.Member

data class DepartmentDto(
    val id: Long,
    val name: String,
    val description: String?,
    val dutyTypes: List<DutyTypeDto>,
    val members: List<MemberDto>,
    val createdDate: String,
    val lastModifiedDate: String,
    val manager: String?,
) {
    companion object {
        fun ofSimple(department: Department): DepartmentDto {
            return of(department, mutableListOf(), mutableListOf())
        }

        fun of(department: Department, members: List<Member>, dutyTypes: List<DutyType>): DepartmentDto {
            val sortedTypes = dutyTypes.sortedBy { it.position }
                .map {
                    DutyTypeDto(
                        it.id,
                        it.name,
                        it.position,
                        it.color.toString()
                    )
                }.toMutableList()
            sortedTypes.add(0, DutyTypeDto(name = "OFF", position = -1, color = department.offColor.toString()))

            return DepartmentDto(
                id = department.id!!,
                name = department.name,
                description = department.description,
                dutyTypes = sortedTypes,
                members = members.map { MemberDto.ofSimple(it) },
                createdDate = department.createdDate.toString(),
                lastModifiedDate = department.modifiedDate.toString(),
                manager = department.manager?.name,
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
