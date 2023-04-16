package com.tistory.shanepark.dutypark.department.service

import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentCreateDto
import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentDto
import com.tistory.shanepark.dutypark.department.domain.dto.SimpleDepartmentDto
import com.tistory.shanepark.dutypark.department.domain.entity.Department
import com.tistory.shanepark.dutypark.department.repository.DepartmentRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class DepartmentService(
    private val repository: DepartmentRepository,
    private val dutyRepository: DutyRepository,
) {

    @Transactional(readOnly = true)
    fun findAllWithMemberCount(pageable: Pageable): Page<SimpleDepartmentDto> {
        return repository.findAllWithMemberCount(pageable)
    }

    @Transactional(readOnly = true)
    fun findById(id: Long): DepartmentDto {
        val withMembers = repository.findByIdWithMembers(id).orElseThrow()
        val withDutyTypes = repository.findByIdWithDutyTypes(id).orElseThrow()

        return DepartmentDto.of(
            department = withMembers,
            members = withMembers.members,
            dutyTypes = withDutyTypes.dutyTypes
        )
    }

    fun create(departmentCreateDto: DepartmentCreateDto): DepartmentDto {
        Department(departmentCreateDto.name).let {
            it.description = departmentCreateDto.description
            repository.save(it)
            return DepartmentDto.of(it)
        }
    }

    fun delete(id: Long) {
        val department = repository.findById(id).orElseThrow()
        if (department.members.isNotEmpty()) {
            throw IllegalStateException("Department has members")
        }
        val dutyTypes = department.dutyTypes
        dutyRepository.setDutyTypeNullIfDutyTypeIn(dutyTypes)

        repository.deleteById(id)
    }

    fun isDuplicated(name: String): Boolean {
        repository.findByName(name).let {
            return it != null
        }
    }

    fun addMemberToDepartment(department: Department, member: Member) {
        if (member.department != null) {
            throw IllegalStateException("The member already belongs to department")
        }
        department.addMember(member)
    }

    fun removeMemberFromDepartment(department: Department, member: Member) {
        if (member.department != department) {
            throw IllegalStateException("Member does not belong to department")
        }
        department.removeMember(member)
    }

}
