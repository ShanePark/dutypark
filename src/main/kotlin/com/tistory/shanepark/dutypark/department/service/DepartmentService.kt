package com.tistory.shanepark.dutypark.department.service

import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentCreateDto
import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentDto
import com.tistory.shanepark.dutypark.department.domain.dto.SimpleDepartmentDto
import com.tistory.shanepark.dutypark.department.domain.entity.Department
import com.tistory.shanepark.dutypark.department.repository.DepartmentRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class DepartmentService(
    private val departmentRepository: DepartmentRepository,
    private val dutyRepository: DutyRepository,
    private val memberRepository: MemberRepository
) {

    @Transactional(readOnly = true)
    fun findAllWithMemberCount(pageable: Pageable): Page<SimpleDepartmentDto> {
        return departmentRepository.findAllWithMemberCount(pageable)
    }

    @Transactional(readOnly = true)
    fun findByIdWithMembersAndDutyTypes(id: Long): DepartmentDto {
        val withMembers = departmentRepository.findByIdWithMembers(id).orElseThrow()
        val withDutyTypes = departmentRepository.findByIdWithDutyTypes(id).orElseThrow()

        return DepartmentDto.of(
            department = withMembers,
            members = withMembers.members,
            dutyTypes = withDutyTypes.dutyTypes
        )
    }

    @Transactional(readOnly = true)
    fun findByIdWithDutyTypes(id: Long): DepartmentDto {
        val withDutyTypes = departmentRepository.findByIdWithDutyTypes(id).orElseThrow()
        return DepartmentDto.of(
            department = withDutyTypes,
            members = emptyList(),
            dutyTypes = withDutyTypes.dutyTypes
        )
    }

    fun create(departmentCreateDto: DepartmentCreateDto): DepartmentDto {
        Department(departmentCreateDto.name).let {
            it.description = departmentCreateDto.description
            departmentRepository.save(it)
            return DepartmentDto.ofSimple(it)
        }
    }

    fun delete(id: Long) {
        val department = departmentRepository.findById(id).orElseThrow()
        if (department.members.isNotEmpty()) {
            throw IllegalStateException("Department has members")
        }
        val dutyTypes = department.dutyTypes
        dutyRepository.setDutyTypeNullIfDutyTypeIn(dutyTypes)

        departmentRepository.deleteById(id)
    }

    fun isDuplicated(name: String): Boolean {
        departmentRepository.findByName(name).let {
            return it != null
        }
    }

    fun addMemberToDepartment(departmentId: Long, memberId: Long) {
        val department = departmentRepository.findById(departmentId).orElseThrow()
        val member = memberRepository.findById(memberId).orElseThrow()

        if (member.department != null) {
            throw IllegalStateException("The member already belongs to department")
        }
        department.addMember(member)
    }

    fun removeMemberFromDepartment(departmentId: Long, memberId: Long) {
        val department = departmentRepository.findById(departmentId).orElseThrow()
        val member = memberRepository.findById(memberId).orElseThrow()

        if (member.department != department) {
            throw IllegalStateException("Member does not belong to department")
        }
        department.removeMember(member)
    }

    fun changeManager(departmentId: Long, memberId: Long?) {
        val department = departmentRepository.findById(departmentId).orElseThrow()
        val member = memberId?.let { memberRepository.findById(memberId).orElseThrow() }

        department.changeManager(member)
        departmentRepository.save(department)
    }

}
